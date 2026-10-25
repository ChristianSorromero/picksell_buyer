<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f9f8f6; padding: 40px 16px; color: #1b1b1b; }
    .wrap { max-width: 480px; margin: 0 auto; }
    .top-bar { height: 4px; border-radius: 4px 4px 0 0; background: #ff6f61; }
    .card { background: #fff; border-radius: 0 0 12px 12px; padding: 40px 40px 32px; }
    .brand { font-size: 1.1rem; font-weight: 800; color: #c93a2b; letter-spacing: -0.3px; margin-bottom: 32px; }
    .brand span { color: #1b1b1b; }
    h1 { font-size: 1.35rem; font-weight: 700; margin-bottom: 12px; line-height: 1.3; }
    p { font-size: 0.9rem; color: #4b5563; line-height: 1.75; margin-bottom: 14px; }
    .code { font-size: 2rem; font-weight: 800; letter-spacing: 10px; color: #1b1b1b; background: #faebe8; border-radius: 10px; padding: 16px; text-align: center; margin: 24px 0; }
    .footer { margin-top: 24px; text-align: center; font-size: 0.72rem; color: #9ca3af; line-height: 1.7; }
</style>
</head>
<body>
<div class="wrap">
    <div class="top-bar"></div>
    <div class="card">
        <div class="brand">Pick<span>Sell</span></div>

        <h1>Reset your password</h1>
        <p>Hi <strong>{{ $user->first_name }}</strong>,</p>
        <p>Enter this code in the PickSell app to choose a new password:</p>

        <div class="code">{{ $code }}</div>

        <p>The code expires in {{ $minutes }} minutes. If you didn't ask to reset your password, ignore this email — your password stays the same.</p>
    </div>
    <div class="footer">PickSell &middot; Never share this code with anyone.</div>
</div>
</body>
</html>
