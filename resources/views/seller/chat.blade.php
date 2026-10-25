@extends('seller.layout')
@section('title', 'Chat / Messaging')

@section('styles')
<style>
    .chat-layout { display: grid; grid-template-columns: 280px 1fr; gap: 0; height: calc(100vh - 120px); background: #fff; border-radius: 12px; border: 1px solid #e8e2d8; overflow: hidden; }
    .chat-sidebar { border-right: 1px solid #f0ebe0; display: flex; flex-direction: column; }
    .chat-sidebar-header { padding: 1rem; border-bottom: 1px solid #f0ebe0; }
    .chat-search { width: 100%; padding: 0.5rem 0.8rem; border: 1.5px solid #ddd6c8; border-radius: 8px; font-size: 0.85rem; background: var(--bone); outline: none; }
    .chat-search:focus { border-color: var(--coral); }
    .chat-list { flex: 1; overflow-y: auto; }
    .chat-item { display: flex; align-items: center; gap: 0.7rem; padding: 0.8rem 1rem; cursor: pointer; border-bottom: 1px solid #fafaf8; transition: background 0.15s; text-decoration: none; color: inherit; }
    .chat-item:hover, .chat-item.active { background: #fff3f0; }
    .chat-avatar { width: 38px; height: 38px; border-radius: 50%; color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 0.9rem; flex-shrink: 0; }
    .chat-avatar.buyer { background: #2563eb; }
    .chat-avatar.admin { background: #E8472A; }
    .chat-item-info { flex: 1; min-width: 0; }
    .chat-item-name { font-size: 0.88rem; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .chat-item-preview { font-size: 0.78rem; color: #aaa; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .chat-main { display: flex; flex-direction: column; }
    .chat-header { padding: 1rem 1.2rem; border-bottom: 1px solid #f0ebe0; display: flex; align-items: center; gap: 0.8rem; }
    .chat-messages { flex: 1; overflow-y: auto; padding: 1.2rem; display: flex; flex-direction: column; gap: 0.8rem; background: #fafaf8; }
    .msg { max-width: 65%; }
    .msg.sent { align-self: flex-end; }
    .msg.received { align-self: flex-start; }
    .msg-bubble { padding: 0.6rem 0.9rem; border-radius: 12px; font-size: 0.88rem; line-height: 1.5; }
    .msg.sent .msg-bubble { background: var(--coral); color: #fff; border-bottom-right-radius: 4px; }
    .msg.received .msg-bubble { background: #fff; border: 1px solid #e8e2d8; border-bottom-left-radius: 4px; }
    .msg-time { font-size: 0.72rem; color: #aaa; margin-top: 0.2rem; }
    .msg.sent .msg-time { text-align: right; }
    .chat-input-area { padding: 1rem; border-top: 1px solid #f0ebe0; display: flex; gap: 0.6rem; }
    .chat-input { flex: 1; padding: 0.65rem 1rem; border: 1.5px solid #ddd6c8; border-radius: 8px; font-size: 0.9rem; outline: none; font-family: inherit; }
    .chat-input:focus { border-color: var(--coral); }
    .chat-empty { flex: 1; display: flex; align-items: center; justify-content: center; color: #aaa; font-size: 0.9rem; background: #fafaf8; }
    .unread-badge { background: var(--coral); color: #fff; font-size: 0.65rem; font-weight: 700; padding: 0.1rem 0.45rem; border-radius: 999px; margin-left: auto; }
</style>
@endsection

@section('content')
<div class="chat-layout">
    <div class="chat-sidebar">
        <div class="chat-sidebar-header">
            <input type="text" class="chat-search" placeholder="Search..." oninput="filterUsers(this.value)">
        </div>
        <div class="chat-list" id="userList">
            @forelse($users as $user)
            <a href="/seller/chat?user={{ $user->id }}" class="chat-item {{ $activeUser && $activeUser->id === $user->id ? 'active' : '' }}" data-name="{{ strtolower($user->full_name) }}">
                <div class="chat-avatar {{ $user->role }}">{{ strtoupper(substr($user->first_name, 0, 1)) }}</div>
                <div class="chat-item-info">
                    <div class="chat-item-name">{{ $user->role === 'admin' ? 'PickSell Support' : $user->full_name }}</div>
                    <div class="chat-item-preview">{{ $user->role === 'admin' ? 'Customer support' : ucfirst($user->role) }}</div>
                </div>
                @if($user->unread > 0)
                <span class="unread-badge">{{ $user->unread }}</span>
                @endif
            </a>
            @empty
            <div style="padding:1.5rem;text-align:center;color:#aaa;font-size:0.85rem;">No contacts yet.</div>
            @endforelse
        </div>
    </div>

    <div class="chat-main">
        @if($activeUser)
        <div class="chat-header">
            <div class="chat-avatar {{ $activeUser->role }}">{{ strtoupper(substr($activeUser->first_name, 0, 1)) }}</div>
            <div>
                <div style="font-weight:700;font-size:0.95rem;">{{ $activeUser->role === 'admin' ? 'PickSell Support' : $activeUser->full_name }}</div>
                <div style="font-size:0.78rem;color:#aaa;">{{ $activeUser->role === 'admin' ? 'Customer support' : ucfirst($activeUser->role).' · '.$activeUser->email }}</div>
            </div>
        </div>
        <div class="chat-messages" id="chatMessages">
            @if(isset($product) && $product)
            <div style="display:flex;align-items:center;gap:0.8rem;background:#fff8f0;border:1px solid #fde8cc;border-radius:10px;padding:0.8rem 1rem;margin-bottom:0.5rem;">
                @if($product->image)
                <img src="{{ Storage::url($product->image) }}" style="width:56px;height:56px;object-fit:cover;border-radius:8px;flex-shrink:0;">
                @endif
                <div style="flex:1;min-width:0;">
                    <div style="font-size:0.75rem;color:#b45309;font-weight:600;margin-bottom:0.2rem;">Inquiring about</div>
                    <div style="font-size:0.88rem;font-weight:700;color:#92400e;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{{ $product->name }}</div>
                    <div style="font-size:0.85rem;color:var(--coral);font-weight:700;">₱{{ number_format($product->effective_price, 2) }}</div>
                </div>
            </div>
            @endif
            @forelse($messages as $msg)
            <div class="msg {{ $msg->sender_id === auth()->id() ? 'sent' : 'received' }}">
                <div class="msg-bubble">{{ $msg->body }}</div>
                <div class="msg-time">{{ $msg->created_at->forDisplay()->format('M d, h:i A') }}</div>
            </div>
            @empty
            <div style="text-align:center;color:#aaa;font-size:0.85rem;margin-top:2rem;">No messages yet. Start the conversation!</div>
            @endforelse
        </div>
        <div class="chat-input-area">
            <form method="POST" action="/seller/chat/send" style="display:flex;gap:0.6rem;flex:1;">
                @csrf
                <input type="hidden" name="receiver_id" value="{{ $activeUser->id }}">
                <input type="text" name="body" class="chat-input" placeholder="Type a message..." required autocomplete="off">
                <button type="submit" class="btn btn-coral">Send</button>
            </form>
        </div>
        @else
        <div class="chat-empty">💬 Select a contact to start messaging</div>
        @endif
    </div>
</div>
<script>
const msgs = document.getElementById('chatMessages');
if (msgs) msgs.scrollTop = msgs.scrollHeight;
function filterUsers(val) {
    document.querySelectorAll('#userList .chat-item').forEach(item => {
        item.style.display = item.dataset.name.includes(val.toLowerCase()) ? 'flex' : 'none';
    });
}
</script>
@endsection
