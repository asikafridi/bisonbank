(function () {
    'use strict';

    // ── DOM refs ──
    const pages = {
        atm: document.getElementById('page-atm'),
        features: document.getElementById('page-features'),
        developers: document.getElementById('page-developers'),
    };
    const navButtons = document.querySelectorAll('.navbar-links button');
    const brandLink = document.getElementById('brandLink');

    const commandInput = document.getElementById('commandInput');
    const screenContent = document.getElementById('screenContent');
    const enterBtn = document.getElementById('enterBtn');
    const backToTopBtn = document.getElementById('backToTop');

    const modeToggle = document.getElementById('modeToggle');
    const modeStatus = document.getElementById('modeStatus');
    const roleBadge = document.getElementById('roleBadge');
    const keypad = document.getElementById('keypad');

    let currentMode = 'user'; // 'user' or 'admin'

    // ── Navigation ──
    function showPage(pageId) {
        Object.keys(pages).forEach(key => {
            pages[key].classList.toggle('hidden', key !== pageId);
        });
        navButtons.forEach(btn => {
            btn.classList.toggle('active', btn.dataset.page === pageId);
        });
        if (pageId === 'atm') {
            setTimeout(() => commandInput.focus(), 150);
        }
        const container = document.querySelector('.app-wrapper');
        if (container) {
            container.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    navButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            showPage(btn.dataset.page);
        });
    });

    brandLink.addEventListener('click', (e) => {
        e.preventDefault();
        showPage('atm');
    });

    // ── Back to Top ──
    window.addEventListener('scroll', () => {
        backToTopBtn.classList.toggle('visible', window.scrollY > 300);
    });
    backToTopBtn.addEventListener('click', () => {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    });

    // ── ATM functions ──
    function appendToScreen(text) {
        let current = screenContent.textContent;
        if (current.length > 0 && !current.endsWith('\n')) {
            screenContent.textContent += '\n';
        }
        screenContent.textContent += text;
        screenContent.scrollTop = screenContent.scrollHeight;
    }

    async function sendCommand(cmd) {
        if (!cmd.trim()) return;
        appendToScreen('> ' + cmd);
        try {
            const res = await fetch('/command', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ command: cmd.trim() })
            });
            if (!res.ok) {
                const errText = await res.text();
                appendToScreen('Error: ' + errText);
                return;
            }
            const data = await res.json();
            let resp = data.response || '(no response)';
            if (!resp.endsWith('\n')) resp += '\n';
            appendToScreen(resp);
        } catch (err) {
            appendToScreen('⚠️ Could not reach backend. Make sure server is running.');
            console.error(err);
        }
        screenContent.scrollTop = screenContent.scrollHeight;
    }

    enterBtn.addEventListener('click', () => {
        const cmd = commandInput.value;
        if (cmd.trim()) {
            sendCommand(cmd);
            commandInput.value = '';
        }
    });

    commandInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            enterBtn.click();
        }
    });

    // ── Mode Toggle ──
    function updateMode(mode) {
        currentMode = mode;
        const screen = document.querySelector('.atm-screen');
        if (mode === 'admin') {
            modeToggle.classList.add('admin');
            modeStatus.textContent = 'Current: Admin';
            roleBadge.innerHTML = '<i class="fas fa-circle" style="font-size:8px;margin-right:6px;color:#fbbf24;"></i> Admin';
            if (screen) screen.classList.add('admin-active');
        } else {
            modeToggle.classList.remove('admin');
            modeStatus.textContent = 'Current: User';
            roleBadge.innerHTML = '<i class="fas fa-circle" style="font-size:8px;margin-right:6px;color:#00d4ff;"></i> User';
            if (screen) screen.classList.remove('admin-active');
        }
        renderKeypad();
    }

    modeToggle.addEventListener('click', () => {
        const newMode = currentMode === 'user' ? 'admin' : 'user';
        updateMode(newMode);
    });

    // ── Keypad rendering ──
    const userCommands = [
        { cmd: 'CREATE ACCOUNT ', icon: 'fa-user-plus', label: 'Create' },
        { cmd: 'LOGIN ', icon: 'fa-sign-in-alt', label: 'Login' },
        { cmd: 'VERIFY ', icon: 'fa-check-circle', label: 'Verify' },
        { cmd: 'LOGOUT', icon: 'fa-sign-out-alt', label: 'Logout' },
        { cmd: 'BALANCE', icon: 'fa-wallet', label: 'Balance' },
        { cmd: 'DEPOSIT ', icon: 'fa-arrow-down', label: 'Deposit' },
        { cmd: 'WITHDRAW ', icon: 'fa-arrow-up', label: 'Withdraw' },
        { cmd: 'TRANSFER ', icon: 'fa-exchange-alt', label: 'Transfer' },
        { cmd: 'PAY BILL ', icon: 'fa-receipt', label: 'Pay Bill' },
        { cmd: 'STATEMENT', icon: 'fa-list-ul', label: 'Statement' },
        { cmd: 'CHANGE PIN ', icon: 'fa-key', label: 'Change PIN' },
        { cmd: 'SET CITY ', icon: 'fa-map-pin', label: 'Set City' },
        { cmd: 'AUTHORIZE ', icon: 'fa-shield-alt', label: 'Authorize' },
        { cmd: 'HELP', icon: 'fa-question-circle', label: 'Help' },
    ];

    const adminCommands = [
        { cmd: 'ADMIN LOGIN 9999', icon: 'fa-user-cog', label: 'Admin Login' },
        { cmd: 'VIEW ALL', icon: 'fa-eye', label: 'View All' },
        { cmd: 'NEW DAY', icon: 'fa-sun', label: 'New Day' },
    ];

    function renderKeypad() {
        let buttons = [...userCommands];
        if (currentMode === 'admin') {
            buttons = buttons.concat(adminCommands.map(c => ({ ...c, admin: true })));
        }
        keypad.innerHTML = '';
        buttons.forEach(cmdObj => {
            const btn = document.createElement('button');
            btn.className = 'key';
            if (cmdObj.admin) btn.classList.add('admin-only');
            btn.setAttribute('data-cmd', cmdObj.cmd);
            btn.innerHTML = `<i class="fas ${cmdObj.icon}"></i> ${cmdObj.label}`;
            btn.addEventListener('click', () => {
                commandInput.value = cmdObj.cmd;
                commandInput.focus();
                commandInput.setSelectionRange(cmdObj.cmd.length, cmdObj.cmd.length);
            });
            keypad.appendChild(btn);
        });
    }

    // ── Features: Build command grid ──
    const commands = [
        { badge: 'CREATE ACCOUNT', usage: 'CREATE ACCOUNT &lt;name&gt; &lt;PIN&gt; &lt;city&gt; &lt;answer&gt;', desc: 'Open a new account with personal details.' },
        { badge: 'LOGIN', usage: 'LOGIN &lt;AcNo&gt; &lt;PIN&gt;', desc: 'Log in to your account using AcNo and PIN.' },
        { badge: 'VERIFY', usage: 'VERIFY &lt;OTP&gt;', desc: 'Complete 2FA with the OTP sent during login.' },
        { badge: 'LOGOUT', usage: 'LOGOUT', desc: 'End your current session.' },
        { badge: 'BALANCE', usage: 'BALANCE', desc: 'Check your current account balance.' },
        { badge: 'DEPOSIT', usage: 'DEPOSIT &lt;amt&gt;', desc: 'Add funds to your account.' },
        { badge: 'WITHDRAW', usage: 'WITHDRAW &lt;amt&gt;', desc: 'Withdraw funds (city-location & daily limit enforced).' },
        { badge: 'TRANSFER', usage: 'TRANSFER &lt;amt&gt; TO &lt;name&gt;', desc: 'Send money to another account.' },
        { badge: 'PAY BILL', usage: 'PAY BILL &lt;type&gt; &lt;amt&gt;', desc: 'Pay a utility bill (electricity, gas, etc.).' },
        { badge: 'STATEMENT', usage: 'STATEMENT', desc: 'View your transaction history.' },
        { badge: 'CHANGE PIN', usage: 'CHANGE PIN &lt;old&gt; &lt;new&gt;', desc: 'Update your account PIN.' },
        { badge: 'SET CITY', usage: 'SET CITY &lt;city&gt;', desc: 'Set your current city for location-based security.' },
        { badge: 'AUTHORIZE', usage: 'AUTHORIZE &lt;answer&gt;', desc: 'Approve a transaction blocked due to city mismatch.' },
        { badge: 'ADMIN LOGIN', usage: 'ADMIN LOGIN 9999', desc: 'Access admin mode (PIN: 9999).' },
        { badge: 'VIEW ALL', usage: 'VIEW ALL', desc: '(Admin) List all registered accounts.' },
        { badge: 'NEW DAY', usage: 'NEW DAY', desc: 'Reset daily withdrawal limits for all accounts.' },
        { badge: 'HELP', usage: 'HELP', desc: 'Display the command reference.' },
        { badge: 'EXIT', usage: 'EXIT', desc: 'Close the ATM simulator.' },
    ];

    const grid = document.getElementById('commandGrid');
    commands.forEach(cmd => {
        const div = document.createElement('div');
        div.className = 'cmd-item fade-up';
        div.innerHTML = `
      <div class="cmd-header">
        <span class="cmd-badge">${cmd.badge}</span>
        <button class="copy-btn" data-cmd="${cmd.usage}"><i class="fas fa-copy"></i></button>
      </div>
      <p class="cmd-desc">${cmd.desc}</p>
      <span class="cmd-usage">Usage: ${cmd.usage}</span>
    `;
        grid.appendChild(div);
    });

    // ── Features: Search ──
    const searchInput = document.getElementById('commandSearch');
    searchInput.addEventListener('input', () => {
        const query = searchInput.value.toLowerCase();
        document.querySelectorAll('.cmd-item').forEach(el => {
            const text = el.textContent.toLowerCase();
            el.classList.toggle('hidden', !text.includes(query));
        });
    });

    // ── Features: Copy to Clipboard ──
    document.addEventListener('click', (e) => {
        const btn = e.target.closest('.copy-btn');
        if (!btn) return;
        const cmd = btn.getAttribute('data-cmd') || '';
        navigator.clipboard.writeText(cmd).then(() => {
            const icon = btn.querySelector('i');
            const originalClass = icon.className;
            icon.className = 'fas fa-check';
            btn.classList.add('copied');
            setTimeout(() => {
                icon.className = originalClass;
                btn.classList.remove('copied');
            }, 2000);
        }).catch(() => {
            // fallback
            const textArea = document.createElement('textarea');
            textArea.value = cmd;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            const icon = btn.querySelector('i');
            const originalClass = icon.className;
            icon.className = 'fas fa-check';
            btn.classList.add('copied');
            setTimeout(() => {
                icon.className = originalClass;
                btn.classList.remove('copied');
            }, 2000);
        });
    });

    // ── Features: Accordion ──
    document.querySelectorAll('.accordion-header').forEach(header => {
        header.addEventListener('click', () => {
            const item = header.parentElement;
            const isActive = item.classList.contains('active');
            const parent = item.parentElement;
            parent.querySelectorAll('.accordion-item').forEach(child => {
                child.classList.remove('active');
            });
            if (!isActive) {
                item.classList.add('active');
            }
        });
    });

    // ── Developers: Click to expand ──
    document.querySelectorAll('.dev-card').forEach(card => {
        const btn = card.querySelector('.expand-btn');
        card.addEventListener('click', (e) => {
            if (e.target.closest('.links a')) return;
            if (e.target.closest('.expand-btn')) return;
            card.classList.toggle('expanded');
        });
        if (btn) {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                card.classList.toggle('expanded');
            });
        }
    });

    // ── Scroll-triggered fade-in ──
    const fadeElements = document.querySelectorAll('.cmd-item, .dev-card, .course-info-card, .accordion-item');
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
            }
        });
    }, { threshold: 0.1 });
    fadeElements.forEach(el => {
        el.classList.add('fade-up');
        observer.observe(el);
    });

    // ── Image fallback ──
    document.querySelectorAll('.dev-card .avatar img').forEach(img => {
        img.addEventListener('error', function () {
            this.style.display = 'none';
            const parent = this.parentElement;
            if (parent) {
                parent.textContent = '👤';
                parent.style.fontSize = '32px';
                parent.style.display = 'flex';
                parent.style.alignItems = 'center';
                parent.style.justifyContent = 'center';
            }
        });
    });

    // ── Init ──
    updateMode('user');
    showPage('atm');

})();