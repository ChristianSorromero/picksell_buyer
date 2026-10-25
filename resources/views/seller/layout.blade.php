<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/png" href="{{ asset('images/transparent logo.png') }}">
    <title>PickSell Seller — @yield('title')</title>
    <script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>
    <style>
        :root {
            --coral: #E8472A; --coral-dark: #c93a20;
            --charcoal: #2D2D2D; --bone: #F5F0E8; --bone-dark: #ede7d9;
            --sidebar-w: 240px; --sidebar-mini: 64px;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body, body *, body *::before, body *::after { transition: background-color 0.35s ease, color 0.35s ease, border-color 0.35s ease, box-shadow 0.35s ease; }
        body { font-family: 'Segoe UI', sans-serif; background: #f4f4f4; color: var(--charcoal); display: flex; min-height: 100vh; }
        body.dark { background: #111; color: #e5e7eb; }
        body.dark .topbar { background: #1a1a1a; border-color: #2a2a2a; }
        body.dark .topbar-title { color: #f3f4f6; }
        body.dark .topbar-right span { color: #9ca3af; }
        body.dark .main, body.dark .content { background: #111; }
        body.dark .card,
        body.dark .stat-card,
        body.dark .modal { background: #1e1e1e; border-color: #2a2a2a; color: #e5e7eb; }
        body.dark .card-header { border-color: #2a2a2a; }
        body.dark .card-title { color: #f3f4f6; }
        body.dark .stat-card-label { color: #9ca3af; }
        body.dark table { color: #e5e7eb; }
        body.dark th { color: #9ca3af; border-color: #2a2a2a; }
        body.dark td { border-color: #2a2a2a; color: #e5e7eb; }
        body.dark tr:hover td { background: #252525; }
        body.dark .form-label { color: #d1d5db; }
        body.dark .form-control,
        body.dark .search-input,
        body.dark .filter-select { background: #2a2a2a; border-color: #3a3a3a; color: #f3f4f6; }
        body.dark .form-control:focus { background: #333; border-color: var(--coral); }
        body.dark .btn-outline { border-color: #3a3a3a; color: #d1d5db; }
        body.dark .btn-outline:hover { border-color: var(--coral); color: var(--coral); }
        body.dark .alert-success { background: #052e16; border-color: #166534; color: #86efac; }
        body.dark .alert-error { background: #2d0a0a; border-color: #991b1b; color: #fca5a5; }
        body.dark .admin-card { background: #252525; }
        body.dark .admin-name { color: #f3f4f6; }
        body.dark .admin-role { color: #9ca3af; }
        body.dark #logoutModal > div { background: #1e1e1e; color: #e5e7eb; }
        body.dark #logoutModal > div div[style*='color:#888'] { color: #9ca3af !important; }
        body.dark #logoutModal button[style*='background:#fff'] { background: #2a2a2a !important; color: #e5e7eb !important; border-color: #3a3a3a !important; }
        body.dark .badge-pending    { background: #2d1f00; color: #fbbf24; }
        body.dark .badge-approved,
        body.dark .badge-completed,
        body.dark .badge-active,
        body.dark .badge-shipped    { background: #052e16; color: #86efac; }
        body.dark .badge-disapproved,
        body.dark .badge-suspended,
        body.dark .badge-cancelled  { background: #2d0a0a; color: #fca5a5; }
        body.dark .badge-deactivated,
        body.dark .badge-archived   { background: #1f1f1f; color: #9ca3af; }
        body.dark .badge-buyer      { background: #0c1a3a; color: #93c5fd; }
        body.dark .badge-seller     { background: #052e16; color: #86efac; }
        body.dark .badge-courier    { background: #2d1500; color: #fdba74; }
        body.dark .badge-processing { background: #0c1a3a; color: #93c5fd; }
        .dm-toggle { position: fixed; bottom: 1.2rem; right: 1.2rem; width: 42px; height: 42px; border-radius: 50%; background: #2D2D2D; color: #fff; border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 12px rgba(0,0,0,0.25); z-index: 9999; transition: background 0.2s; }
        .dm-toggle:hover { background: var(--coral); }
        a { text-decoration: none; color: inherit; }

        .sidebar { width: var(--sidebar-w); background: var(--charcoal); color: #fff; display: flex; flex-direction: column; position: fixed; top: 0; left: 0; height: 100vh; z-index: 50; overflow: hidden; transition: width 0.25s ease; }
        .sidebar.mini { width: var(--sidebar-mini); }
        .sidebar-logo { padding: 1rem 1.2rem; border-bottom: 1px solid #3a3a3a; display: flex; align-items: center; justify-content: space-between; min-height: 60px; }
        .sidebar-logo-text { display: flex; flex-direction: column; overflow: hidden; }
        .sidebar-logo a { color: var(--coral); font-size: 1.4rem; font-weight: 800; letter-spacing: -1px; white-space: nowrap; }
        .sidebar-logo a span { color: #fff; }
        .sidebar-logo small { display: block; color: #888; font-size: 0.72rem; margin-top: 0.1rem; letter-spacing: 0.05em; text-transform: uppercase; white-space: nowrap; }
        .sidebar.mini .sidebar-logo-text { display: none; }
        .hamburger { background: none; border: none; color: #aaa; cursor: pointer; padding: 0.3rem; border-radius: 6px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; transition: color 0.2s; }
        .hamburger:hover { color: #fff; }

        .sidebar-nav { flex: 1; padding: 1rem 0; overflow-y: auto; scrollbar-width: thin; scrollbar-color: #3a3a3a var(--charcoal); }
        .sidebar-nav::-webkit-scrollbar { width: 4px; }
        .sidebar-nav::-webkit-scrollbar-track { background: var(--charcoal); }
        .sidebar-nav::-webkit-scrollbar-thumb { background: #3a3a3a; border-radius: 999px; }
        .nav-group-label { font-size: 0.68rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: #666; padding: 0.8rem 1.2rem 0.3rem; white-space: nowrap; overflow: hidden; }
        .sidebar.mini .nav-group-label { height: 0; padding: 0; overflow: hidden; }
        .nav-divider { display: none; border: none; border-top: 1px solid #3a3a3a; margin: 4px 12px; }
        .sidebar.mini .nav-divider { display: block; }
        .nav-item { display: flex; align-items: center; gap: 0.7rem; padding: 0.65rem 1.2rem; color: #bbb; font-size: 0.88rem; transition: all 0.15s; cursor: pointer; white-space: nowrap; }
        .nav-item:hover { background: #3a3a3a; color: #fff; }
        .nav-item.active { background: rgba(232,71,42,0.15); color: var(--coral); border-right: 3px solid var(--coral); }
        .nav-item .icon { width: 20px; text-align: center; flex-shrink: 0; }
        .nav-item .nav-label { overflow: hidden; transition: opacity 0.2s; }
        .sidebar.mini .nav-item .nav-label { opacity: 0; width: 0; }
        .sidebar.mini .nav-item { justify-content: center; padding: 0.65rem 0; }
        .sidebar.mini .nav-item.active { border-right: none; border-left: 3px solid var(--coral); }
        .nav-badge { margin-left: auto; background: var(--coral); color: #fff; font-size: 0.65rem; font-weight: 700; padding: 0.1rem 0.45rem; border-radius: 999px; }
        .sidebar.mini .nav-badge { display: none; }

        .sidebar-footer { padding: 1rem; border-top: 1px solid #3a3a3a; background: var(--charcoal); }
        .admin-card { background: #3a3a3a; border-radius: 10px; padding: 0.8rem 1rem; }
        .admin-info { display: flex; align-items: center; gap: 0.7rem; }
        .admin-avatar { width: 36px; height: 36px; background: var(--coral); border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 0.9rem; flex-shrink: 0; text-decoration: none; color: #fff; }
        .admin-text { flex: 1; min-width: 0; overflow: hidden; transition: opacity 0.2s; }
        .admin-name { font-size: 0.85rem; font-weight: 600; white-space: nowrap; }
        .admin-role { font-size: 0.72rem; color: #888; white-space: nowrap; }
        .sidebar.mini .admin-text { opacity: 0; width: 0; }
        .sidebar.mini .btn-logout { display: none; }
        .sidebar.mini .admin-card { padding: 0.5rem; display: flex; justify-content: center; }
        .btn-logout { background: transparent; border: 1px solid #555; color: #aaa; border-radius: 8px; padding: 0.35rem 0.5rem; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
        .btn-logout:hover { border-color: var(--coral); color: var(--coral); }

        .main { margin-left: var(--sidebar-w); flex: 1; display: flex; flex-direction: column; min-height: 100vh; transition: margin-left 0.25s ease; }
        .main.mini { margin-left: var(--sidebar-mini); }

        .topbar { background: #fff; border-bottom: 1px solid #e8e2d8; padding: 0 1.5rem; height: 60px; display: flex; align-items: center; justify-content: space-between; position: sticky; top: 0; z-index: 40; }
        .topbar-title { font-size: 1.1rem; font-weight: 700; }
        .topbar-right { display: flex; align-items: center; gap: 1rem; }

        .content { padding: 1.5rem; flex: 1; }

        .stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
        .stat-card { background: #fff; border-radius: 12px; padding: 1.2rem; border: 1px solid #e8e2d8; }
        .stat-card-icon { font-size: 1.5rem; margin-bottom: 0.5rem; }
        .stat-card-num { font-size: 1.8rem; font-weight: 800; }
        .stat-card-label { font-size: 0.78rem; color: #888; margin-top: 0.2rem; }
        .stat-card.coral .stat-card-num { color: var(--coral); }
        .stat-card.green .stat-card-num { color: #16a34a; }
        .stat-card.blue .stat-card-num { color: #2563eb; }
        .stat-card.orange .stat-card-num { color: #d97706; }
        .stat-card.red .stat-card-num { color: #dc2626; }

        .card { background: #fff; border-radius: 12px; border: 1px solid #e8e2d8; overflow: hidden; margin-bottom: 1.5rem; }
        .card-header { padding: 1rem 1.2rem; border-bottom: 1px solid #f0ebe0; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 0.5rem; }
        .card-title { font-size: 0.95rem; font-weight: 700; }
        .card-body { padding: 1.2rem; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { text-align: left; padding: 0.6rem 0.8rem; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: #888; border-bottom: 1px solid #f0ebe0; }
        td { padding: 0.7rem 0.8rem; border-bottom: 1px solid #f8f4ee; vertical-align: middle; }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background: #fafaf8; }

        .badge { display: inline-block; padding: 0.2rem 0.6rem; border-radius: 999px; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; }
        .badge-pending    { background: #fff8e1; color: #b45309; }
        .badge-processing { background: #eff6ff; color: #2563eb; }
        .badge-shipped    { background: #f0fdf4; color: #16a34a; }
        .badge-completed  { background: #f0fdf4; color: #16a34a; }
        .badge-cancelled  { background: #fef2f0; color: #dc2626; }
        .badge-active     { background: #f0fdf4; color: #16a34a; }
        .badge-archived   { background: #f4f4f4; color: #888; }

        .btn { display: inline-block; padding: 0.4rem 0.9rem; border-radius: 6px; font-size: 0.82rem; font-weight: 600; cursor: pointer; border: none; transition: all 0.2s; }
        .btn-coral { background: var(--coral); color: #fff; }
        .btn-coral:hover { background: var(--coral-dark); }
        .btn-outline { background: transparent; border: 1.5px solid #ddd6c8; color: var(--charcoal); }
        .btn-outline:hover { border-color: var(--coral); color: var(--coral); }
        .btn-danger { background: #dc2626; color: #fff; }
        .btn-danger:hover { background: #b91c1c; }
        .btn-success { background: #16a34a; color: #fff; }
        .btn-success:hover { background: #15803d; }
        .btn-sm { padding: 0.3rem 0.7rem; font-size: 0.78rem; }

        .form-group { margin-bottom: 1rem; }
        .form-label { display: block; font-size: 0.82rem; font-weight: 600; margin-bottom: 0.35rem; }
        .form-control { width: 100%; padding: 0.6rem 0.9rem; border: 1.5px solid #ddd6c8; border-radius: 8px; font-size: 0.88rem; background: var(--bone); color: var(--charcoal); outline: none; transition: border-color 0.2s; font-family: inherit; }
        .form-control:focus { border-color: var(--coral); background: #fff; }
        textarea.form-control { resize: vertical; min-height: 80px; }

        .alert { padding: 0.7rem 1rem; border-radius: 8px; font-size: 0.85rem; margin-bottom: 1rem; }
        .alert-success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #166534; }
        .alert-error   { background: #fef2f0; border: 1px solid #f5c6be; color: #c0392b; }

        .filters { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; }
        .filter-select { padding: 0.4rem 0.7rem; border: 1.5px solid #ddd6c8; border-radius: 6px; font-size: 0.82rem; background: #fff; outline: none; cursor: pointer; }
        .filter-select:focus { border-color: var(--coral); }
        .search-input { padding: 0.4rem 0.8rem; border: 1.5px solid #ddd6c8; border-radius: 6px; font-size: 0.82rem; background: #fff; outline: none; }
        .search-input:focus { border-color: var(--coral); }

        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }
        @media(max-width: 768px) { .grid-2 { grid-template-columns: 1fr; } }

        /* Modal */
        .modal-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 200; align-items: center; justify-content: center; }
        .modal-overlay.open { display: flex; }
        .modal { background: #fff; border-radius: 14px; padding: 1.5rem; width: 100%; max-width: 520px; margin: 1rem; max-height: 90vh; overflow-y: auto; }
        .modal-title { font-size: 1rem; font-weight: 700; margin-bottom: 1rem; }
        .modal-footer { display: flex; gap: 0.8rem; justify-content: flex-end; margin-top: 1rem; }
        @media(max-width: 768px) {
            .sidebar { width: var(--sidebar-mini); }
            .sidebar .sidebar-logo-text, .sidebar .nav-group-label, .sidebar .nav-label, .sidebar .nav-badge, .sidebar .admin-text, .sidebar .btn-logout { display: none; }
            .sidebar .sidebar-logo { justify-content: center; padding: 1rem 0.7rem; }
            .sidebar .nav-divider { display: block; }
            .sidebar .nav-item { justify-content: center; padding: 0.7rem 0; }
            .sidebar .admin-card { padding: 0.5rem; display: flex; justify-content: center; }
            .main, .main.mini { margin-left: var(--sidebar-mini); }
            .topbar { padding: 0 1rem; }
            .topbar-title { font-size: 0.95rem; }
            .content { padding: 1rem; min-width: 0; }
            .topbar-right span { display: none; }
            .card-body { padding: 1rem; }
            table { display: block; overflow-x: auto; white-space: nowrap; }
            .modal-footer { flex-wrap: wrap; }
        }
        @media(max-width: 420px) {
            .content { padding: 0.75rem; }
            .stat-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.6rem; }
            .stat-card { padding: 0.85rem; }
            .stat-card-num { font-size: 1.45rem; }
            .card-header { align-items: flex-start; }
            .filters { width: 100%; }
            .filters > * { min-width: 0; max-width: 100%; }
        }
        @media(min-width: 1440px) {
            :root { --sidebar-w: 280px; --sidebar-mini: 72px; }
            .content { padding: clamp(1.5rem, 3vw, 4rem); }
            .topbar { padding-inline: clamp(1.5rem, 3vw, 4rem); }
            .stat-grid { grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1.25rem; }
            .stat-card { padding: 1.5rem; }
            .card-body { padding: 1.5rem; }
        }
        @media (min-width: 769px) and (max-width: 1100px) {
            .sidebar { width: var(--sidebar-mini); }
            .sidebar .sidebar-logo-text, .sidebar .nav-group-label, .sidebar .nav-label, .sidebar .nav-badge, .sidebar .admin-text, .sidebar .btn-logout { display: none; }
            .sidebar .sidebar-logo { justify-content: center; padding-inline: 0.7rem; }
            .sidebar .nav-divider { display: block; }
            .sidebar .nav-item { justify-content: center; padding-inline: 0; }
            .main, .main.mini { margin-left: var(--sidebar-mini); }
            .content { padding: 1.25rem; }
            .stat-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
            .grid-2 { grid-template-columns: 1fr; }
        }
        @media (max-width: 640px) {
            .topbar { min-height: 60px; height: auto; padding-block: 0.75rem; gap: 0.75rem; }
            .topbar-title { min-width: 0; overflow-wrap: anywhere; }
            .content { overflow-x: hidden; }
            .card-header { align-items: flex-start; }
            .card-header .btn { flex-shrink: 0; }
            .filters { width: 100%; }
            .filters > * { flex: 1 1 140px; }
            .modal { padding: 1.1rem; margin: 0.65rem; }
            .modal-footer { justify-content: stretch; }
            .modal-footer .btn { flex: 1; }
        }
    </style>
    @yield('styles')
    @include('partials.pagination-styles')
</head>
<body>
    <aside class="sidebar" id="sidebar">
        <div class="sidebar-logo">
            <div class="sidebar-logo-text">
                <a href="/seller/dashboard">Pick<span>Sell</span></a>
                <small>Seller Panel</small>
            </div>
            <button class="hamburger" onclick="toggleSidebar()">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 24 24"><path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/></svg>
            </button>
        </div>
        <nav class="sidebar-nav">
            <div class="nav-group-label">Overview</div>
            <hr class="nav-divider">
            <a href="/seller/dashboard" class="nav-item {{ request()->is('seller/dashboard') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/></svg></span>
                <span class="nav-label">Dashboard</span>
            </a>

            <div class="nav-group-label">Store</div>
            <hr class="nav-divider">
            <a href="/seller/inventory" class="nav-item {{ request()->is('seller/inventory*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M20 6h-2.18c.07-.44.18-.88.18-1.36C18 2.06 15.94 0 13.36 0c-1.3 0-2.48.52-3.36 1.36C9.12.52 7.94 0 6.64 0 4.06 0 2 2.06 2 4.64c0 .48.11.92.18 1.36H0v14c0 1.1.9 2 2 2h20c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-6.64-4c1.28 0 2.28 1 2.28 2.28 0 .48-.11.92-.28 1.36h-4c-.17-.44-.28-.88-.28-1.36C11.08 3 12.08 2 13.36 2zM6.64 2c1.28 0 2.28 1 2.28 2.28 0 .48-.11.92-.28 1.36h-4c-.17-.44-.28-.88-.28-1.36C4.36 3 5.36 2 6.64 2zM20 18H4V8h16v10z"/></svg></span>
                <span class="nav-label">Inventory</span>
            </a>
            <a href="/seller/orders" class="nav-item {{ request()->is('seller/orders*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 3c1.93 0 3.5 1.57 3.5 3.5S13.93 13 12 13s-3.5-1.57-3.5-3.5S10.07 6 12 6zm7 13H5v-.23c0-.62.28-1.2.76-1.58C7.47 15.82 9.64 15 12 15s4.53.82 6.24 2.19c.48.38.76.97.76 1.58V19z"/></svg></span>
                <span class="nav-label">Orders</span>
            </a>
            <a href="/seller/returns" class="nav-item {{ request()->is('seller/returns*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/></svg></span>
                <span class="nav-label">Returns</span>
            </a>
            <a href="/seller/payouts" class="nav-item {{ request()->is('seller/payouts*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M21 18v1c0 1.1-.9 2-2 2H5c-1.11 0-2-.9-2-2V5c0-1.1.89-2 2-2h14c1.1 0 2 .9 2 2v1h-9c-1.11 0-2 .9-2 2v8c0 1.1.89 2 2 2h9zm-9-2h10V8H12v8zm4-2.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z"/></svg></span>
                <span class="nav-label">Payouts</span>
            </a>

            <div class="nav-group-label">Analytics</div>
            <hr class="nav-divider">
            <a href="/seller/reports" class="nav-item {{ request()->is('seller/reports*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z"/></svg></span>
                <span class="nav-label">Reports</span>
            </a>

            <div class="nav-group-label">System</div>
            <hr class="nav-divider">
            <a href="/seller/chat" class="nav-item {{ request()->is('seller/chat*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z"/></svg></span>
                <span class="nav-label">Chat / Messaging</span>
            </a>
            <a href="/seller/account" class="nav-item {{ request()->is('seller/account*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg></span>
                <span class="nav-label">My Account</span>
            </a>
        </nav>
        <div class="sidebar-footer">
            <div class="admin-card">
                <div class="admin-info">
                    <a href="/seller/account" class="admin-avatar">{{ strtoupper(substr(auth()->user()->first_name, 0, 1)) }}</a>
                    <div class="admin-text">
                        <a href="/seller/account" style="text-decoration:none;color:inherit;">
                            <div class="admin-name">{{ auth()->user()->full_name }}</div>
                            <div class="admin-role">{{ auth()->user()->business_name ?? 'Seller' }}</div>
                        </a>
                    </div>
                    <form method="POST" action="/logout" id="logoutForm">
                        @csrf
                        <button type="button" class="btn-logout" title="Logout" onclick="document.getElementById('logoutModal').style.display='flex'">
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5-5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"/></svg>
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </aside>

    <div class="main" id="main">
        <div class="topbar">
            <div class="topbar-title">@yield('title')</div>
            <div class="topbar-right">
                @include('partials.dashboard-clock')
            </div>
        </div>
        <div class="content">
            @php
                $announcements = \App\Models\Announcement::where('active', true)
                    ->where(fn($q) => $q->where('audience', 'all')->orWhere('audience', 'seller'))
                    ->latest()->get();
            @endphp
            @foreach($announcements as $ann)
            <div class="seller-announcement" data-announcement-id="{{ $ann->id }}" style="background:#fff8e1;border:1px solid #fde68a;border-radius:8px;padding:0.7rem 1rem;margin-bottom:0.8rem;display:flex;align-items:flex-start;gap:0.7rem;font-size:0.85rem;">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="#d97706" viewBox="0 0 24 24" style="flex-shrink:0;margin-top:1px;"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>
                <div style="flex:1;"><strong>{{ $ann->title }}</strong> — {{ $ann->message }}</div>
                <button type="button" aria-label="Close announcement" title="Close" onclick="dismissSellerAnnouncement(this)" style="border:0;background:transparent;color:#8a6a16;font-size:1.1rem;line-height:1;cursor:pointer;padding:0 .2rem;">&times;</button>
            </div>
            @endforeach
            @if(session('success'))
                <div class="alert alert-success">{{ session('success') }}</div>
            @endif
            @if($errors->any())
                <div class="alert alert-error">{{ $errors->first() }}</div>
            @endif
            @yield('content')
        </div>
    </div>

<script>
function toggleSidebar() {
    const s = document.getElementById('sidebar');
    const m = document.getElementById('main');
    s.classList.toggle('mini');
    m.classList.toggle('mini');
    localStorage.setItem('sellerSidebarMini', s.classList.contains('mini'));
}
if (localStorage.getItem('sellerSidebarMini') === 'true') {
    document.getElementById('sidebar').classList.add('mini');
    document.getElementById('main').classList.add('mini');
}
function toggleDark() {
    document.body.classList.toggle('dark');
    localStorage.setItem('sellerDark', document.body.classList.contains('dark'));
}
if (localStorage.getItem('sellerDark') === 'true') document.body.classList.add('dark');
</script>
<script>
function dismissSellerAnnouncement(button) {
    const banner = button.closest('[data-announcement-id]');
    const dismissed = JSON.parse(localStorage.getItem('dismissedSellerAnnouncements') || '[]');
    const id = Number(banner.dataset.announcementId);
    if (!dismissed.includes(id)) dismissed.push(id);
    localStorage.setItem('dismissedSellerAnnouncements', JSON.stringify(dismissed));
    banner.remove();
}
document.querySelectorAll('.seller-announcement').forEach(banner => {
    const dismissed = JSON.parse(localStorage.getItem('dismissedSellerAnnouncements') || '[]');
    if (dismissed.includes(Number(banner.dataset.announcementId))) banner.remove();
});
</script>

<button class="dm-toggle" onclick="toggleDark()" title="Toggle dark mode">
    <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="currentColor" viewBox="0 0 24 24"><path d="M12 3a9 9 0 1 0 9 9c0-.46-.04-.92-.1-1.36a5.389 5.389 0 0 1-4.4 2.26 5.403 5.403 0 0 1-3.14-9.8c-.44-.06-.9-.1-1.36-.1z"/></svg>
</button>

<!-- Logout Modal -->
<div id="logoutModal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:999;align-items:center;justify-content:center;">
    <div style="background:#fff;border-radius:14px;padding:2rem;width:100%;max-width:360px;margin:1rem;text-align:center;box-shadow:0 8px 32px rgba(0,0,0,0.15);">
        <div style="width:52px;height:52px;background:#fff3f0;border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 1rem;"><svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" fill="#E8472A" viewBox="0 0 24 24"><path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5-5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"/></svg></div>
        <div style="font-size:1.1rem;font-weight:700;margin-bottom:0.4rem;">Log Out?</div>
        <div style="font-size:0.88rem;color:#888;margin-bottom:1.5rem;">Are you sure you want to log out of your seller account?</div>
        <div style="display:flex;gap:0.8rem;justify-content:center;">
            <button onclick="document.getElementById('logoutModal').style.display='none'" style="padding:0.6rem 1.4rem;border:1.5px solid #ddd6c8;border-radius:8px;background:#fff;font-size:0.88rem;font-weight:600;cursor:pointer;">Cancel</button>
            <button onclick="document.getElementById('logoutForm').submit()" style="padding:0.6rem 1.4rem;border:none;border-radius:8px;background:#E8472A;color:#fff;font-size:0.88rem;font-weight:600;cursor:pointer;">Yes, Log Out</button>
        </div>
    </div>
</div>
@yield('scripts')
@include('partials.search-suggestions')
</body>
</html>
