<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f6f6f6; padding: 40px 16px; color: #1a1a1a; }
    .wrap { max-width: 480px; margin: 0 auto; }
    .top-bar { height: 4px; background: #E8472A; border-radius: 4px 4px 0 0; }
    .card { background: #fff; border-radius: 0 0 12px 12px; padding: 40px 40px 32px; }
    .brand { font-size: 1.1rem; font-weight: 800; color: #E8472A; letter-spacing: -0.3px; margin-bottom: 32px; }
    .brand span { color: #1a1a1a; }
    h1 { font-size: 1.35rem; font-weight: 700; color: #1a1a1a; margin-bottom: 12px; line-height: 1.3; }
    p { font-size: 0.9rem; color: #555; line-height: 1.75; margin-bottom: 14px; }
    .code { font-family: 'Courier New', monospace; font-size: 2rem; font-weight: 800; letter-spacing: 0.4em; color: #1a1a1a; background: #fff3f0; border: 1px solid #fcd5cc; border-radius: 10px; padding: 16px 0 16px 0.4em; text-align: center; margin: 8px 0 20px; }
    .divider { border: none; border-top: 1px solid #f0f0f0; margin: 28px 0; }
    .footer { margin-top: 24px; text-align: center; font-size: 0.72rem; color: #bbb; line-height: 1.7; }
</style>
</head>
<body>
<div class="wrap">
    <div class="top-bar"></div>
    <div class="card">
        <div class="brand">Pick<span>Sell</span></div>

        <h1>Verify your email address</h1>
        <p>@if($name)Hi <strong>{{ $name }}</strong>, enter @else Enter @endif this code on the PickSell registration form to confirm your email:</p>

        <div class="code">{{ $code }}</div>

        <p>The code expires in <strong>{{ $minutes }} minutes</strong>. If it expires, request a new one from the registration form.</p>

        <hr class="divider">

        <p>If you did not create a PickSell account, you can ignore this email. Never share this code with anyone, including PickSell staff.</p>
    </div>
    <div class="footer">&copy; {{ date('Y') }} PickSell. This is an automated message.</div>
</div>
</body>
</html>
