<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\NewMessageMail;
use App\Models\Message;
use App\Models\Order;
use App\Models\User;
use App\Support\BuyerPresenter;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Throwable;

/**
 * Buyer chat with the website's rules (BuyerController::chat/sendMessage): approved sellers the
 * buyer has messaged or ordered from, and PickSell support once the buyer has written to it.
 * Messages are the same rows the seller and admin chat pages show.
 */
class ChatController extends Controller
{
    /** Users a buyer may talk to: any admin, or an approved seller. */
    private function reachable()
    {
        return User::where(fn ($q) => $q->where('role', 'admin')
            ->orWhere(fn ($seller) => $seller->where('role', 'seller')->where('status', 'approved')));
    }

    private function thread(int $buyerId, int $otherId)
    {
        return Message::where(fn ($q) => $q->where('sender_id', $buyerId)->where('receiver_id', $otherId))
            ->orWhere(fn ($q) => $q->where('sender_id', $otherId)->where('receiver_id', $buyerId));
    }

    public function contacts(Request $request)
    {
        $buyer = $request->user();
        $chattedIds = Message::where(fn ($q) => $q->where('sender_id', $buyer->id)->orWhere('receiver_id', $buyer->id))
            ->get(['sender_id', 'receiver_id'])
            ->map(fn ($m) => $m->sender_id === $buyer->id ? $m->receiver_id : $m->sender_id)->unique();
        $orderedSellerIds = Order::where('buyer_id', $buyer->id)->pluck('seller_id');

        $sellers = User::whereIn('id', $chattedIds->merge($orderedSellerIds)->unique())
            ->where('role', 'seller')->where('status', 'approved')->get();
        $admins = User::whereIn('id', $chattedIds)->where('role', 'admin')->get();

        $contacts = $admins->concat($sellers)->map(function (User $u) use ($buyer) {
            $last = $this->thread($buyer->id, $u->id)->latest()->latest('id')->first();

            return [
                'id'           => $u->id,
                'name'         => $u->role === 'admin' ? 'PickSell Support' : ($u->business_name ?: $u->full_name),
                'initials'     => strtoupper(substr($u->first_name ?? '?', 0, 1).substr($u->last_name ?? '', 0, 1)),
                'role'         => $u->role,
                'last_message' => $last?->body ?? '',
                'last_time'    => BuyerPresenter::date($last?->created_at),
                'unread'       => Message::where('sender_id', $u->id)->where('receiver_id', $buyer->id)->where('read', false)->count(),
            ];
        })->sortByDesc('last_time')->values();

        return response()->json(['contacts' => $contacts]);
    }

    public function messages(Request $request, int $userId)
    {
        $buyer = $request->user();
        $other = $this->reachable()->whereKey($userId)->firstOrFail();

        Message::where('sender_id', $other->id)->where('receiver_id', $buyer->id)->update(['read' => true]);
        $messages = $this->thread($buyer->id, $other->id)->with('product')->orderBy('created_at')->orderBy('id')->get();

        return response()->json(['messages' => $messages->map(fn (Message $m) => $this->messagePayload($m, $buyer))->values()]);
    }

    public function send(Request $request)
    {
        $data = $request->validate([
            'receiver_id' => 'required|integer',
            'body'        => 'required|string|max:2000',
            'product_id'  => 'nullable|exists:products,id',
        ]);
        $buyer = $request->user();
        $receiver = $this->reachable()->whereKey($data['receiver_id'])->firstOrFail();
        abort_if($receiver->id === $buyer->id, 422, 'You cannot message your own account.');

        $message = Message::create([
            'sender_id'   => $buyer->id,
            'receiver_id' => $receiver->id,
            'body'        => $data['body'],
            'product_id'  => $data['product_id'] ?? null,
            'read'        => false,
        ]);

        // The same in-app alert and email the website sends for a new message.
        $receiver->notifications()->create([
            'id'   => (string) Str::uuid(),
            'type' => 'App\\Notifications\\BuyerOrderUpdate',
            'data' => json_encode([
                'type' => 'message',
                'order_id' => null,
                'order_number' => null,
                'message' => 'You have a new message from '.$buyer->full_name.'.',
            ]),
        ]);
        try {
            Mail::to($receiver->email)->send(new NewMessageMail($message->load('sender', 'receiver', 'product')));
        } catch (Throwable $exception) {
            Log::warning('Chat message email notification failed.', ['message_id' => $message->id, 'error' => $exception->getMessage()]);
        }

        return response()->json($this->messagePayload($message, $buyer), 201);
    }

    private function messagePayload(Message $m, User $buyer): array
    {
        return [
            'id'         => $m->id,
            'body'       => $m->body,
            'sender_id'  => $m->sender_id,
            'created_at' => BuyerPresenter::date($m->created_at),
            'is_mine'    => $m->sender_id === $buyer->id,
            'product'    => $m->product ? ['id' => $m->product->id, 'name' => $m->product->name, 'image' => BuyerPresenter::image($m->product->primary_image)] : null,
        ];
    }
}
