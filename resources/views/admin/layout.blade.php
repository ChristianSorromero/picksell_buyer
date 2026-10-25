<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/png" href="{{ asset('images/transparent logo.png') }}">
    <title>PickSell Admin — @yield('title')</title>
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
        body.dark .main { background: #111; }
        body.dark .content { background: #111; }
        body.dark .card,
        body.dark .stat-card { background: #1e1e1e; border-color: #2a2a2a; color: #e5e7eb; }
        body.dark .card-header { border-color: #2a2a2a; }
        body.dark .card-title { color: #f3f4f6; }
        body.dark .card-body { color: #e5e7eb; }
        body.dark .stat-card-label { color: #9ca3af; }
        body.dark .stat-card-num { color: inherit; }
        body.dark table { color: #e5e7eb; }
        body.dark th { color: #9ca3af; border-color: #2a2a2a; }
        body.dark td { border-color: #2a2a2a; color: #e5e7eb; }
        body.dark tr:hover td { background: #252525; }
        body.dark .form-group .form-label { color: #d1d5db; }
        body.dark .form-control,
        body.dark .search-input,
        body.dark .filter-select { background: #2a2a2a; border-color: #3a3a3a; color: #f3f4f6; }
        body.dark .form-control:focus { background: #333; border-color: var(--coral); }
        body.dark .btn-outline { border-color: #3a3a3a; color: #d1d5db; }
        body.dark .btn-outline:hover { border-color: var(--coral); color: var(--coral); }
        body.dark .alert-success { background: #052e16; border-color: #166534; color: #86efac; }
        body.dark .alert-error { background: #2d0a0a; border-color: #991b1b; color: #fca5a5; }
        body.dark .alert-warning { background: #2d1f00; border-color: #854d0e; color: #fcd34d; }
        body.dark .notif-dropdown { background: #1e1e1e; border-color: #2a2a2a; }
        body.dark .notif-item { border-color: #2a2a2a; color: #d1d5db; }
        body.dark .notif-header { border-color: #2a2a2a; color: #f3f4f6; }
        body.dark .notif-empty { color: #6b7280; }
        body.dark .admin-card { background: #252525; }
        body.dark .admin-name { color: #f3f4f6; }
        body.dark .admin-role { color: #9ca3af; }
        body.dark .modal-overlay .modal,
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

        /* Sidebar */
        .sidebar {
            width: var(--sidebar-w); background: var(--charcoal); color: #fff;
            display: flex; flex-direction: column; position: fixed; top: 0; left: 0;
            height: 100vh; z-index: 50; overflow: hidden;
            transition: width 0.25s ease;
        }
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
        .admin-card { background: #1f1f21; border: 1px solid #363639; border-radius: 14px; padding: 0.65rem 0.7rem; box-shadow: 0 8px 22px rgba(0,0,0,.12); transition: border-color .25s, background .25s, transform .25s; }
        .admin-card:hover { border-color: #4a4a4d; background: #242426; transform: translateY(-1px); }
        .admin-info { display: flex; align-items: center; gap: 0.65rem; }
        .admin-avatar { width: 36px; height: 36px; background: #f4f1eb; border: 2px solid #4a4a4d; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 0.88rem; flex-shrink: 0; text-decoration: none; color: var(--charcoal); transition: border-color .25s, transform .25s; }
        .admin-avatar:hover { border-color: var(--coral); transform: scale(1.05); }
        .admin-text { flex: 1; min-width: 0; overflow: hidden; transition: opacity 0.2s; }
        .admin-name { color: #f4f1eb; font-size: 0.78rem; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .admin-role { color: #99999f; font-size: 0.68rem; margin-top: 0.12rem; white-space: nowrap; }
        .sidebar.mini .admin-text { opacity: 0; width: 0; }
        .sidebar.mini .btn-logout { display: none; }
        .sidebar.mini .admin-card { padding: 0.5rem; display: flex; justify-content: center; }
        .btn-logout { background: transparent; border: 1px solid #454549; color: #aaa; border-radius: 8px; padding: 0.42rem 0.48rem; cursor: pointer; transition: background .2s, border-color .2s, color .2s, transform .2s; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
        .btn-logout:hover { background: var(--coral); border-color: var(--coral); color: #fff; transform: translateX(2px); box-shadow: 0 5px 12px rgba(232,71,42,.28); }

        /* Main */
        .main { margin-left: var(--sidebar-w); flex: 1; display: flex; flex-direction: column; min-height: 100vh; transition: margin-left 0.25s ease; }
        .main.mini { margin-left: var(--sidebar-mini); }

        /* Topbar */
        .topbar { background: #fff; border-bottom: 1px solid #e8e2d8; padding: 0 1.5rem; height: 60px; display: flex; align-items: center; justify-content: space-between; position: sticky; top: 0; z-index: 40; }
        .topbar-title { font-size: 1.1rem; font-weight: 700; }
        .topbar-right { display: flex; align-items: center; gap: 1rem; }
        .notif-btn { position: relative; background: none; border: none; font-size: 1.2rem; cursor: pointer; }
        .notif-dot { position: absolute; top: 0; right: 0; width: 8px; height: 8px; background: var(--coral); border-radius: 50%; display:none; }
        .notif-dropdown { position: absolute; top: 48px; right: 1.5rem; width: 320px; background: #fff; border: 1px solid #e8e2d8; border-radius: 12px; box-shadow: 0 8px 32px rgba(0,0,0,0.12); z-index: 100; display: none; max-height: 400px; overflow-y: auto; }
        .notif-dropdown.open { display: block; }
        .notif-item { padding: 0.8rem 1rem; border-bottom: 1px solid #f0ebe0; font-size: 0.83rem; color: #444; }
        .notif-item:last-child { border-bottom: none; }
        .notif-empty { padding: 1.5rem; text-align: center; color: #aaa; font-size: 0.85rem; }
        .notif-header { padding: 0.8rem 1rem; font-weight: 700; font-size: 0.85rem; border-bottom: 1px solid #f0ebe0; display:flex; justify-content:space-between; align-items:center; }

        /* Content */
        .content { padding: 1.5rem; flex: 1; }

        /* Cards */
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

        /* Table */
        .card { background: #fff; border-radius: 12px; border: 1px solid #e8e2d8; overflow: hidden; margin-bottom: 1.5rem; }
        .card-header { padding: 1rem 1.2rem; border-bottom: 1px solid #f0ebe0; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 0.5rem; }
        .card-title { font-size: 0.95rem; font-weight: 700; }
        .card-body { padding: 1.2rem; }
        table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        th { text-align: left; padding: 0.6rem 0.8rem; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: #888; border-bottom: 1px solid #f0ebe0; }
        td { padding: 0.7rem 0.8rem; border-bottom: 1px solid #f8f4ee; vertical-align: middle; }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background: #fafaf8; }

        /* Badges */
        .badge { display: inline-block; padding: 0.2rem 0.6rem; border-radius: 999px; font-size: 0.72rem; font-weight: 700; text-transform: uppercase; }
        .badge-pending  { background: #fff8e1; color: #b45309; }
        .badge-approved { background: #f0fdf4; color: #16a34a; }
        .badge-disapproved { background: #fef2f0; color: #dc2626; }
        .badge-suspended { background: #fef2f0; color: #dc2626; }
        .badge-deactivated { background: #f4f4f4; color: #888; }
        .badge-buyer   { background: #eff6ff; color: #2563eb; }
        .badge-seller  { background: #f0fdf4; color: #16a34a; }
        .badge-courier { background: #fff7ed; color: #d97706; }

        /* Buttons */
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

        /* Form */
        .form-group { margin-bottom: 1rem; }
        .form-label { display: block; font-size: 0.82rem; font-weight: 600; margin-bottom: 0.35rem; }
        .form-control { width: 100%; padding: 0.6rem 0.9rem; border: 1.5px solid #ddd6c8; border-radius: 8px; font-size: 0.88rem; background: var(--bone); color: var(--charcoal); outline: none; transition: border-color 0.2s; font-family: inherit; }
        .form-control:focus { border-color: var(--coral); background: #fff; }
        textarea.form-control { resize: vertical; min-height: 100px; }

        /* Alert */
        .alert { padding: 0.7rem 1rem; border-radius: 8px; font-size: 0.85rem; margin-bottom: 1rem; }
        .alert-success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #166534; }
        .alert-error   { background: #fef2f0; border: 1px solid #f5c6be; color: #c0392b; }
        .alert-warning { background: #fffbeb; border: 1px solid #fde68a; color: #92400e; }

        /* Filters */
        .filters { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; }
        .filter-select { padding: 0.4rem 0.7rem; border: 1.5px solid #ddd6c8; border-radius: 6px; font-size: 0.82rem; background: #fff; outline: none; cursor: pointer; }
        .filter-select:focus { border-color: var(--coral); }
        .search-input { padding: 0.4rem 0.8rem; border: 1.5px solid #ddd6c8; border-radius: 6px; font-size: 0.82rem; background: #fff; outline: none; }
        .search-input:focus { border-color: var(--coral); }

        /* Grid 2 col */
        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }
        @media(max-width: 768px) { .grid-2 { grid-template-columns: 1fr; } }
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
            .topbar-right > span { display: none; }
            .content { padding: 1rem; min-width: 0; }
            .card-body { padding: 1rem; }
            table { display: block; overflow-x: auto; white-space: nowrap; }
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
    </style>
    @yield('styles')
    @include('partials.pagination-styles')
</head>
<body>
    <!-- Sidebar -->
    <aside class="sidebar" id="sidebar">
        <div class="sidebar-logo">
            <div class="sidebar-logo-text">
                <a href="/admin/dashboard">Pick<span>Sell</span></a>
                <small>Admin Panel</small>
            </div>
            <button class="hamburger" onclick="toggleSidebar()">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 24 24"><path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/></svg>
            </button>
        </div>
        <nav class="sidebar-nav">
            <div class="nav-group-label">Overview</div>
            <hr class="nav-divider">
            <a href="/admin/dashboard" class="nav-item {{ request()->is('admin/dashboard') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/></svg></span>
                <span class="nav-label">Dashboard</span>
                @if(isset($stats) && $stats['pending'] > 0)
                    <span class="nav-badge">{{ $stats['pending'] }}</span>
                @endif
            </a>

            <div class="nav-group-label">User Management</div>
            <hr class="nav-divider">
            <a href="/admin/registrations" class="nav-item {{ request()->is('admin/registrations*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6zm-1 1.5L18.5 9H13V3.5zM6 20V4h5v7h7v9H6z"/></svg></span>
                <span class="nav-label">Registrations</span>
            </a>
            <a href="/admin/users" class="nav-item {{ request()->is('admin/users*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/></svg></span>
                <span class="nav-label">User Accounts</span>
            </a>
            <a href="/admin/products" class="nav-item {{ request()->is('admin/products*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M20 6h-2.18c.07-.44.18-.88.18-1.36C18 2.06 15.94 0 13.36 1.36 12.48.52 11.3 0 10 0 7.42 0 5.36 2.06 5.36 4.64c0 .48.11.92.18 1.36H3v14h18V6h-1zM12 2c1.28 0 2.28 1 2.28 2.28 0 .48-.11.92-.28 1.36h-4c-.17-.44-.28-.88-.28-1.36C9.72 3 10.72 2 12 2zM5 8h14v10H5V8z"/></svg></span>
                <span class="nav-label">Products</span>
            </a>

            <div class="nav-group-label">Operations</div>
            <hr class="nav-divider">
            <a href="/admin/compliance" class="nav-item {{ request()->is('admin/compliance*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg></span>
                <span class="nav-label">Seller Compliance</span>
            </a>
            <a href="/admin/complaints" class="nav-item {{ request()->is('admin/complaints*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg></span>
                <span class="nav-label">Complaints</span>
            </a>
            <a href="/admin/returns" class="nav-item {{ request()->is('admin/returns*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/></svg></span>
                <span class="nav-label">Returns &amp; Refunds</span>
            </a>
            <a href="/admin/finance" class="nav-item {{ request()->is('admin/finance*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M21 18v1c0 1.1-.9 2-2 2H5c-1.11 0-2-.9-2-2V5c0-1.1.89-2 2-2h14c1.1 0 2 .9 2 2v1h-9c-1.11 0-2 .9-2 2v8c0 1.1.89 2 2 2h9zm-9-2h10V8H12v8zm4-2.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z"/></svg></span>
                <span class="nav-label">Finance</span>
            </a>
            <a href="/admin/commission" class="nav-item {{ request()->is('admin/commission*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M11.8 10.9c-2.27-.59-3-1.2-3-2.15 0-1.09 1.01-1.85 2.7-1.85 1.78 0 2.44.85 2.5 2.1h2.21c-.07-1.72-1.12-3.3-3.21-3.81V3h-3v2.16c-1.94.42-3.5 1.68-3.5 3.61 0 2.31 1.91 3.46 4.7 4.13 2.5.6 3 1.48 3 2.41 0 .69-.49 1.79-2.7 1.79-2.06 0-2.87-.92-2.98-2.1h-2.2c.12 2.19 1.76 3.42 3.68 3.83V21h3v-2.15c1.95-.37 3.5-1.5 3.5-3.55 0-2.84-2.43-3.81-4.7-4.4z"/></svg></span>
                <span class="nav-label">Commission</span>
            </a>
            <a href="/admin/logistics" class="nav-item {{ request()->is('admin/logistics*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M20 8h-3V4H3c-1.1 0-2 .9-2 2v11h2a3 3 0 0 0 6 0h6a3 3 0 0 0 6 0h2v-5l-3-4zM6 18.5A1.5 1.5 0 1 1 7.5 17 1.5 1.5 0 0 1 6 18.5zM17 9.5h2.5l1.96 2.5H17v-2.5zM19.5 18.5A1.5 1.5 0 1 1 21 17a1.5 1.5 0 0 1-1.5 1.5z"/></svg></span>
                <span class="nav-label">Sorting Center</span>
            </a>

            <div class="nav-group-label">Analytics</div>
            <hr class="nav-divider">
            <a href="/admin/reports" class="nav-item {{ request()->is('admin/reports*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z"/></svg></span>
                <span class="nav-label">Reports</span>
            </a>

            <div class="nav-group-label">System</div>
            <hr class="nav-divider">
            <a href="/admin/settings" class="nav-item {{ request()->is('admin/settings*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94s-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96a7.01 7.01 0 0 0-1.62-.94l-.36-2.54a.484.484 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.47.47 0 0 0-.59.22L2.74 8.87a.47.47 0 0 0 .12.61l2.03 1.58c-.05.3-.07.62-.07.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.37 1.04.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.57 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.47.47 0 0 0-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg></span>
                <span class="nav-label">Platform Settings</span>
            </a>
            <a href="/admin/chat" class="nav-item {{ request()->is('admin/chat*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z"/></svg></span>
                <span class="nav-label">Chat / Messaging</span>
            </a>
            <a href="/admin/account" class="nav-item {{ request()->is('admin/account*') ? 'active' : '' }}">
                <span class="icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg></span>
                <span class="nav-label">My Account</span>
            </a>
        </nav>
        <div class="sidebar-footer">
            <div class="admin-card">
                <div class="admin-info">
                    <a href="/admin/account" class="admin-avatar" title="My Account">{{ strtoupper(substr(auth()->user()->first_name, 0, 1)) }}</a>
                    <div class="admin-text">
                        <a href="/admin/account" style="text-decoration:none;color:inherit;">
                            <div class="admin-name">{{ auth()->user()->full_name }}</div>
                            <div class="admin-role">Administrator</div>
                        </a>
                    </div>
                    <form method="POST" action="/logout" id="logoutForm">
                        @csrf
                        <button type="button" class="btn-logout" title="Logout" onclick="confirmLogout()"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5-5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"/></svg></button>
                    </form>
                </div>
            </div>
        </div>
    </aside>

    <!-- Main -->
    <div class="main" id="main">
        <div class="topbar">
            <div class="topbar-title">@yield('title')</div>
            <div class="topbar-right" style="position:relative;">
                <button class="notif-btn" id="notifBtn" onclick="toggleNotif()"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 24 24"><path d="M12 22c1.1 0 2-.9 2-2h-4a2 2 0 0 0 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"/></svg><span class="notif-dot" id="notifDot"></span></button>
                <div class="notif-dropdown" id="notifDropdown">
                    <div class="notif-header">Notifications <span id="notifCount" style="color:var(--coral);"></span></div>
                    <div id="notifList"><div class="notif-empty">Loading...</div></div>
                </div>
                @include('partials.dashboard-clock')
            </div>
        </div>
        <div class="content">
            @if(session('success'))
                <div class="alert alert-success">{{ session('success') }}</div>
            @endif
            @if(session('warning'))
                <div class="alert alert-warning">{{ session('warning') }}</div>
            @endif
            @if($errors->any())
                <div class="alert alert-error">{{ $errors->first() }}</div>
            @endif
            @yield('content')
        </div>
    </div>
<script>
function confirmLogout() {
    document.getElementById('logoutModal').style.display = 'flex';
}
function toggleSidebar() {
    const s = document.getElementById('sidebar');
    const m = document.getElementById('main');
    s.classList.toggle('mini');
    m.classList.toggle('mini');
    localStorage.setItem('sidebarMini', s.classList.contains('mini'));
}
if (localStorage.getItem('sidebarMini') === 'true') {
    document.getElementById('sidebar').classList.add('mini');
    document.getElementById('main').classList.add('mini');
}
function toggleNotif() {
    const dd = document.getElementById('notifDropdown');
    dd.classList.toggle('open');
    if (dd.classList.contains('open')) loadNotifs();
}
function loadNotifs() {
    fetch('/admin/notifications')
        .then(r => r.json())
        .then(data => {
            const list = document.getElementById('notifList');
            document.getElementById('notifCount').textContent = data.length ? `(${data.length})` : '';
            document.getElementById('notifDot').style.display = data.length ? 'block' : 'none';
            if (!data.length) { list.innerHTML = '<div class="notif-empty">No notifications</div>'; return; }
            list.innerHTML = data.map(n => {
                const msg = JSON.parse(n.data).message || '';
                const time = new Date(n.created_at).toLocaleString();
                return `<div class="notif-item"><div>${msg}</div><div style="font-size:0.75rem;color:#aaa;margin-top:0.2rem;">${time}</div></div>`;
            }).join('');
        });
}
document.addEventListener('click', e => {
    if (!document.getElementById('notifBtn').contains(e.target) && !document.getElementById('notifDropdown').contains(e.target)) {
        document.getElementById('notifDropdown').classList.remove('open');
    }
});
// Check unread on load
fetch('/admin/notifications').then(r=>r.json()).then(data=>{
    if(data.length) document.getElementById('notifDot').style.display='block';
});
</script>
<!-- Dark Mode Toggle -->
<button class="dm-toggle" onclick="toggleDark()" title="Toggle dark mode">
    <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="currentColor" viewBox="0 0 24 24"><path d="M12 3a9 9 0 1 0 9 9c0-.46-.04-.92-.1-1.36a5.389 5.389 0 0 1-4.4 2.26 5.403 5.403 0 0 1-3.14-9.8c-.44-.06-.9-.1-1.36-.1z"/></svg>
</button>
<script>
function toggleDark() {
    document.body.classList.toggle('dark');
    localStorage.setItem('adminDark', document.body.classList.contains('dark'));
}
if (localStorage.getItem('adminDark') === 'true') document.body.classList.add('dark');
</script>
<div id="logoutModal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:999;align-items:center;justify-content:center;">
    <div style="background:#fff;border-radius:14px;padding:2rem;width:100%;max-width:360px;margin:1rem;text-align:center;box-shadow:0 8px 32px rgba(0,0,0,0.15);">
        <div style="width:52px;height:52px;background:#fff3f0;border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 1rem;"><svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" fill="#E8472A" viewBox="0 0 24 24"><path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5-5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"/></svg></div>
        <div style="font-size:1.1rem;font-weight:700;margin-bottom:0.4rem;">Log Out?</div>
        <div style="font-size:0.88rem;color:#888;margin-bottom:1.5rem;">Are you sure you want to log out of your admin account?</div>
        <div style="display:flex;gap:0.8rem;justify-content:center;">
            <button onclick="document.getElementById('logoutModal').style.display='none'" style="padding:0.6rem 1.4rem;border:1.5px solid #ddd6c8;border-radius:8px;background:#fff;font-size:0.88rem;font-weight:600;cursor:pointer;">Cancel</button>
            <button onclick="document.getElementById('logoutForm').submit()" style="padding:0.6rem 1.4rem;border:none;border-radius:8px;background:#E8472A;color:#fff;font-size:0.88rem;font-weight:600;cursor:pointer;">Yes, Log Out</button>
        </div>
    </div>
</div>
@include('partials.search-suggestions')
</body>
</html>
