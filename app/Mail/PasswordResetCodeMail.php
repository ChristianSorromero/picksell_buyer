<?php

namespace App\Mail;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class PasswordResetCodeMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(public User $user, public string $code, public int $minutes) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: "Your PickSell password reset code: {$this->code}");
    }

    public function content(): Content
    {
        return new Content(view: 'emails.password-reset-code');
    }
}
