<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Google SSR Actions - 订阅聚合</title>
  <link rel="stylesheet" href="styles.css" />
  <script>
    // ====================
    // 🔐 安全认证系统 v2
    // ====================
    const AUTH_HASH = "__AUTH_HASH__";
    const AUTH_USER = "__AUTH_USER__";
    
    // SHA-256 哈希计算
    async function sha256(message) {
      const msgBuffer = new TextEncoder().encode(message);
      const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }
    
    // 显示登录对话框
    function showAuth() {
      const mask = document.getElementById('auth-mask');
      const userInput = document.getElementById('auth-user');
      const passInput = document.getElementById('auth-input');
      const err = document.getElementById('auth-err');
      const btn = document.getElementById('auth-btn');
      const wrap = document.querySelector('.wrap');
      
      // 显示遮罩，隐藏内容
      mask.style.display = 'flex';
      if (wrap) wrap.style.display = 'none';
      userInput.focus();
      
      async function submit() {
        const user = userInput.value.trim();
        const pwd = passInput.value || '';
        
        if (!pwd) {
          err.textContent = '请输入密码';
          return;
        }
        
        const h = await sha256(pwd);
        const userRequired = (AUTH_USER || '').trim().length > 0;
        const userOk = userRequired ? (user === (AUTH_USER||'').trim()) : true;
        
        if (userOk && h.toLowerCase() === AUTH_HASH.toLowerCase()) {
          // 认证成功
          try{ 
            localStorage.setItem('gauth', h); 
            localStorage.setItem('guser', user); 
          }catch(e){
            console.error('保存认证信息失败:', e);
          }
          
          // 显示内容
          mask.style.display = 'none';
          if (wrap) wrap.style.display = '';
          
          // 加载动态内容
          setTimeout(() => {
            try {
              if (typeof loadMeta === 'function') loadMeta();
              if (typeof loadDailyChart === 'function') loadDailyChart();
              if (typeof loadSparklines === 'function') loadSparklines();
              if (typeof loadSerpAPIKeys === 'function') loadSerpAPIKeys();
              if (typeof loadRecentUrls === 'function') loadRecentUrls();
              if (typeof loadTrend7Day === 'function') loadTrend7Day();
              if (typeof loadSpeedRanking === 'function') loadSpeedRanking();
            } catch(e) {
              console.error('内容加载出错:', e);
            }
          }, 100);
        } else {
          err.textContent = '用户名或密码错误';
          passInput.value = '';
          passInput.focus();
        }
      }
      
      btn.addEventListener('click', submit);
      passInput.addEventListener('keydown', (e)=>{ if(e.key==='Enter'){ submit(); }});
    }
    
    // 认证检查
    function gate() {
      // 如果不需要认证
      if (!AUTH_HASH || AUTH_HASH.trim() === '' || AUTH_HASH === '__AUTH_HASH__') { 
        const wrap = document.querySelector('.wrap');
        if (wrap) wrap.style.display = '';
        return; 
      }
      
      // 检查已保存的认证信息
      try{
        const tk = localStorage.getItem('gauth');
        const gu = (localStorage.getItem('guser') || '').trim();
        const userRequired = (AUTH_USER || '').trim().length > 0;
        const passOk = !!tk && (tk.toLowerCase() === AUTH_HASH.toLowerCase());
        const userOk = userRequired ? (gu === (AUTH_USER||'').trim()) : true;
        
        if (passOk && userOk) { 
          // 认证通过，显示内容
          const wrap = document.querySelector('.wrap');
          if (wrap) wrap.style.display = '';
          
          // 自动加载内容
          setTimeout(() => {
            try {
              if (typeof loadMeta === 'function') loadMeta();
              if (typeof loadDailyChart === 'function') loadDailyChart();
              if (typeof loadSparklines === 'function') loadSparklines();
              if (typeof loadSerpAPIKeys === 'function') loadSerpAPIKeys();
              if (typeof loadRecentUrls === 'function') loadRecentUrls();
              if (typeof loadTrend7Day === 'function') loadTrend7Day();
              if (typeof loadSpeedRanking === 'function') loadSpeedRanking();
            } catch(e) {
              console.error('自动内容加载出错:', e);
            }
          }, 100);
          return;
        }
      }catch(e){
        console.error('认证检查出错:', e);
      }
      
      // 认证失败，显示登录框
      showAuth();
    }
    
    // 页面加载后立即执行认证检查
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', gate);
    } else {
      gate();
    }
    // 根据是否有配额数据隐藏卡片
    document.addEventListener('DOMContentLoaded', ()=>{
      const qleft = '__QLEFT__'; const qcap = '__QCAP__'; const kok='__KOK__'; const kt='__KTOTAL__';
      const hideQuota = (!qleft || qleft==='0') && (!qcap || qcap==='0') && (!kok || kok==='0') && (!kt || kt==='0');
      if(hideQuota){
        document.querySelectorAll('.stat.quota').forEach(el=>el.style.display='none');
      }
    });
  </script>
</head>
<body>
  <!-- 认证遮罩（未认证时显示） -->
  <div id="auth-mask" class="auth-mask" style="display:none">
    <div class="auth-card">
      <h3 class="auth-title">🔐 访问认证</h3>
      <p class="auth-sub">请输入用户名和密码以查看页面内容</p>
      <input id="auth-user" class="auth-input" type="text" placeholder="输入用户名" autocomplete="username" />
      <input id="auth-input" class="auth-input" type="password" placeholder="输入密码" autocomplete="current-password" />
      <button id="auth-btn" class="auth-btn">进入</button>
      <div id="auth-err" class="auth-err"></div>
    </div>
  </div>
  
  <!-- 主内容（认证成功后显示） -->
  <div class="wrap" style="display:none">
    <div class="header">
      <h1>Google SSR Actions</h1>
      <small>构建时间(中国时区)：__TS_CN__</small>
    </div>
    <div class="subtitle">源 __ALIVE__/__TOTAL__ · 节点 __NODES__ · 新增 __NEW__ · 移除 __REMOVED__ · 今日新源 __DAILY_NEW__</div>
    <div style="text-align: center;"><div class="note">📌 仅展示可用源（自动过滤失效/超额/限速来源）</div></div>

    <div class="stats" id="stats-cards">
      <div class="stat quota" data-hide="q"><div class="num">__QLEFT__</div><div>剩余额度</div></div>
      <div class="stat quota" data-hide="q"><div class="num">__QCAP__</div><div>总额度</div></div>
      <div class="stat quota" data-hide="q"><div class="num">__KOK__/__KTOTAL__</div><div>可用密钥/总密钥</div></div>
      <div class="stat"><div class="num">__NEXT_CN__</div><div>下次更新时间</div></div>
    </div>

    <div class="grid">
      <!-- 基础订阅文件卡片 -->
      <div class="card card-files">
        <h3>🔗 基础订阅文件</h3>
        <div class="file-list">
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/all.txt"><code>all.txt</code></a>
                <span class="file-desc">全量订阅 (文本格式)</span>
              </div>
              <div class="file-stats">
                <span class="nodes-count">__NODES__ 节点</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/all.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/good.txt"><code>good.txt</code></a>
                <span class="file-desc">优秀节点 (高质量筛选)</span>
              </div>
              <div class="file-stats">
                <span class="file-type">TXT</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/good.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/good.yaml"><code>good.yaml</code></a>
                <span class="file-desc">优秀节点 (Clash配置)</span>
              </div>
              <div class="file-stats">
                <span class="file-type">YAML</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/good.yaml', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/speed_ranking.yaml"><code>speed_ranking.yaml</code></a>
                <span class="file-desc">🚀 速度排行 (国内优化)</span>
              </div>
              <div class="file-stats">
                <span class="file-type">YAML</span>
                <span class="speed-badge">⚡ 测速</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/speed_ranking.yaml', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/all.yaml"><code>all.yaml</code></a>
                <span class="file-desc">Clash配置 (完整节点)</span>
              </div>
              <div class="file-stats">
                <span class="file-type">YAML</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/all.yaml', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
        </div>
        
        <!-- 最优秀100个节点 -->
        <div style="margin-top: 20px; padding-top: 20px; border-top: 2px solid rgba(148,163,184,.3);">
          <h4 style="color: #e5e7eb; margin: 0 0 16px; font-size: 16px; font-weight: 600;">⭐ 最优秀100个节点</h4>
          <div class="file-list">
            <div class="file-item">
              <div class="file-info">
                <div class="file-name">
                  <a href="sub/top100.txt"><code>top100.txt</code></a>
                  <span class="file-desc">最优秀100个节点 (文本格式)</span>
                </div>
                <div class="file-stats">
                  <span class="nodes-count">100 节点</span>
                  <span class="file-type">TXT</span>
                </div>
              </div>
              <button onclick="copyFileUrl('sub/top100.txt', this)" class="copy-btn">
                <span class="copy-icon">📋</span>
                <span class="copy-text">复制</span>
              </button>
            </div>
            <div class="file-item">
              <div class="file-info">
                <div class="file-name">
                  <a href="sub/top100_v2ray.txt"><code>top100_v2ray.txt</code></a>
                  <span class="file-desc">V2Ray格式订阅</span>
                </div>
                <div class="file-stats">
                  <span class="file-type">V2Ray</span>
                </div>
              </div>
              <button onclick="copyFileUrl('sub/top100_v2ray.txt', this)" class="copy-btn">
                <span class="copy-icon">📋</span>
                <span class="copy-text">复制</span>
              </button>
            </div>
            <div class="file-item">
              <div class="file-info">
                <div class="file-name">
                  <a href="sub/top100.yaml"><code>top100.yaml</code></a>
                  <span class="file-desc">Clash格式订阅</span>
                </div>
                <div class="file-stats">
                  <span class="file-type">YAML</span>
                </div>
              </div>
              <button onclick="copyFileUrl('sub/top100.yaml', this)" class="copy-btn">
                <span class="copy-icon">📋</span>
                <span class="copy-text">复制</span>
              </button>
            </div>
          </div>
        </div>
        
        <p class="card-note">📌 所有订阅文件可直接访问，无需页面认证</p>
      </div>

      <!-- 客户端分类订阅卡片 -->
      <div class="card card-clients">
        <h3>📱 客户端分类订阅</h3>
        
        <!-- PassWall2 订阅 -->
        <div class="client-section">
          <h4 class="client-title">🔧 PassWall2</h4>
          <div class="file-list">
            <div class="file-item">
              <div class="file-info">
                <div class="file-name">
                  <a href="sub/passwall2/all.txt"><code>all.txt</code></a>
                  <span class="file-desc">全量订阅 (URI格式)</span>
                </div>
                <div class="file-stats">
                  <span class="nodes-count">__NODES__ 节点</span>
                  <span class="client-tag">PassWall2</span>
                </div>
              </div>
              <button onclick="copyFileUrl('sub/passwall2/all.txt', this)" class="copy-btn">
                <span class="copy-icon">📋</span>
                <span class="copy-text">复制</span>
              </button>
            </div>
            <div class="file-item">
              <div class="file-info">
                <div class="file-name">
                  <a href="sub/passwall2/good.txt"><code>good.txt</code></a>
                  <span class="file-desc">高质量订阅</span>
                </div>
                <div class="file-stats">
                  <span class="file-type">TXT</span>
                  <span class="client-tag">PassWall2</span>
                </div>
              </div>
              <button onclick="copyFileUrl('sub/passwall2/good.txt', this)" class="copy-btn">
                <span class="copy-icon">📋</span>
                <span class="copy-text">复制</span>
              </button>
            </div>
          </div>
        </div>
        
        <!-- Clash 订阅 -->
        <div class="client-section">
          <h4 class="client-title">⚡ Clash</h4>
          <div class="file-list">
            <div class="file-item">
              <div class="file-info">
                <div class="file-name">
                  <a href="sub/clash/all.yaml"><code>all.yaml</code></a>
                  <span class="file-desc">全量配置</span>
                </div>
                <div class="file-stats">
                  <span class="nodes-count">__NODES__ 节点</span>
                  <span class="client-tag">Clash</span>
                </div>
              </div>
              <button onclick="copyFileUrl('sub/clash/all.yaml', this)" class="copy-btn">
                <span class="copy-icon">📋</span>
                <span class="copy-text">复制</span>
              </button>
            </div>
            <div class="file-item">
              <div class="file-info">
                <div class="file-name">
                  <a href="sub/clash/good.yaml"><code>good.yaml</code></a>
                  <span class="file-desc">高质量配置</span>
                </div>
                <div class="file-stats">
                  <span class="file-type">YAML</span>
                  <span class="client-tag">Clash</span>
                </div>
              </div>
              <button onclick="copyFileUrl('sub/clash/good.yaml', this)" class="copy-btn">
                <span class="copy-icon">📋</span>
                <span class="copy-text">复制</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 协议分类订阅卡片 -->
      <div class="card card-protocols">
        <h3>📡 协议分类订阅</h3>
        <div class="protocol-grid">
          <div class="protocol-item">
            <h5 class="protocol-name">Shadowsocks</h5>
            <div class="protocol-links">
              <a href="sub/passwall2/ss.txt" class="protocol-link">PassWall2</a>
              <a href="sub/clash/ss.yaml" class="protocol-link">Clash</a>
            </div>
            <span class="protocol-count">__SS_COUNT__ 节点</span>
          </div>
          <div class="protocol-item">
            <h5 class="protocol-name">Trojan</h5>
            <div class="protocol-links">
              <a href="sub/passwall2/trojan.txt" class="protocol-link">PassWall2</a>
              <a href="sub/clash/trojan.yaml" class="protocol-link">Clash</a>
            </div>
            <span class="protocol-count">__TROJAN_COUNT__ 节点</span>
          </div>
          <div class="protocol-item">
            <h5 class="protocol-name">VMess</h5>
            <div class="protocol-links">
              <a href="sub/passwall2/vmess.txt" class="protocol-link">PassWall2</a>
              <a href="sub/clash/vmess.yaml" class="protocol-link">Clash</a>
            </div>
            <span class="protocol-count">__VMESS_COUNT__ 节点</span>
          </div>
          <div class="protocol-item">
            <h5 class="protocol-name">VLESS</h5>
            <div class="protocol-links">
              <a href="sub/passwall2/vless.txt" class="protocol-link">PassWall2</a>
              <a href="sub/clash/vless.yaml" class="protocol-link">Clash</a>
            </div>
            <span class="protocol-count">__VLESS_COUNT__ 节点</span>
          </div>
          <div class="protocol-item">
            <h5 class="protocol-name">Hysteria2</h5>
            <div class="protocol-links">
              <a href="sub/passwall2/hysteria2.txt" class="protocol-link">PassWall2</a>
              <a href="sub/clash/hysteria2.yaml" class="protocol-link">Clash</a>
            </div>
            <span class="protocol-count">__HYSTERIA2_COUNT__ 节点</span>
          </div>
        </div>
      </div>

      <!-- 地区分类订阅卡片 -->
      <div class="card card-regions">
        <h3>🌍 地区分类订阅</h3>
        <div class="region-grid">
          <div class="region-item">
            <h5 class="region-name">🇭🇰 香港</h5>
            <div class="region-links">
              <a href="sub/regions/hk/passwall2.txt" class="region-link">PassWall2</a>
              <a href="sub/regions/hk/clash.yaml" class="region-link">Clash</a>
            </div>
            <span class="region-count">__HK_COUNT__ 节点</span>
          </div>
          <div class="region-item">
            <h5 class="region-name">🇯🇵 日本</h5>
            <div class="region-links">
              <a href="sub/regions/jp/passwall2.txt" class="region-link">PassWall2</a>
              <a href="sub/regions/jp/clash.yaml" class="region-link">Clash</a>
            </div>
            <span class="region-count">__JP_COUNT__ 节点</span>
          </div>
          <div class="region-item">
            <h5 class="region-name">🇺🇸 美国</h5>
            <div class="region-links">
              <a href="sub/regions/us/passwall2.txt" class="region-link">PassWall2</a>
              <a href="sub/regions/us/clash.yaml" class="region-link">Clash</a>
            </div>
            <span class="region-count">__US_COUNT__ 节点</span>
          </div>
          <div class="region-item">
            <h5 class="region-name">🇸🇬 新加坡</h5>
            <div class="region-links">
              <a href="sub/regions/sg/passwall2.txt" class="region-link">PassWall2</a>
              <a href="sub/regions/sg/clash.yaml" class="region-link">Clash</a>
            </div>
            <span class="region-count">__SG_COUNT__ 节点</span>
          </div>
          <div class="region-item">
            <h5 class="region-name">🇹🇼 台湾</h5>
            <div class="region-links">
              <a href="sub/regions/tw/passwall2.txt" class="region-link">PassWall2</a>
              <a href="sub/regions/tw/clash.yaml" class="region-link">Clash</a>
            </div>
            <span class="region-count">__TW_COUNT__ 节点</span>
          </div>
          <div class="region-item">
            <h5 class="region-name">🇰🇷 韩国</h5>
            <div class="region-links">
              <a href="sub/regions/kr/passwall2.txt" class="region-link">PassWall2</a>
              <a href="sub/regions/kr/clash.yaml" class="region-link">Clash</a>
            </div>
            <span class="region-count">__KR_COUNT__ 节点</span>
          </div>
        </div>
      </div>

      <!-- URL源文件卡片 -->
      <div class="card card-sources">
        <h3>📂 URL源文件</h3>
        <div class="file-list">
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/urls.txt"><code>urls.txt</code></a>
                <span class="file-desc">当前可用源</span>
              </div>
              <div class="file-stats">
                <span class="status-badge available">✅ 已验证</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/urls.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/all_urls.txt"><code>all_urls.txt</code></a>
                <span class="file-desc">完整源列表</span>
              </div>
              <div class="file-stats">
                <span class="status-badge complete">📋 完整</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/all_urls.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/google_urls.txt"><code>google_urls.txt</code></a>
                <span class="file-desc">Google发现</span>
              </div>
              <div class="file-stats">
                <span class="count-badge">__GCOUNT__ 个</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/google_urls.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/github_urls.txt"><code>github_urls.txt</code></a>
                <span class="file-desc">GitHub发现</span>
              </div>
              <div class="file-stats">
                <span class="count-badge">__GHCOUNT__ 个</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/github_urls.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/telegram_urls.txt"><code>telegram_urls.txt</code></a>
                <span class="file-desc">Telegram发现</span>
              </div>
              <div class="file-stats">
                <span class="count-badge">__TGCOUNT__ 个</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/telegram_urls.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
        </div>
      </div>

      <!-- 辅助输出卡片 -->
      <div class="card card-extras">
        <h3>🛠️ 辅助输出</h3>
        <div class="file-list">
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/github.txt"><code>github.txt</code></a>
                <span class="file-desc">GitHub节点</span>
              </div>
              <div class="file-stats">
                <span class="file-type">TXT</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/github.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="sub/proto/ss-base64.txt"><code>ss-base64.txt</code></a>
                <span class="file-desc">SS Base64编码</span>
              </div>
              <div class="file-stats">
                <span class="file-type">Base64</span>
              </div>
            </div>
            <button onclick="copyFileUrl('sub/proto/ss-base64.txt', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
          <div class="file-item">
            <div class="file-info">
              <div class="file-name">
                <a href="health.json"><code>health.json</code></a>
                <span class="file-desc">健康状态API</span>
              </div>
              <div class="file-stats">
                <span class="file-type">JSON</span>
              </div>
            </div>
            <button onclick="copyFileUrl('health.json', this)" class="copy-btn">
              <span class="copy-icon">📋</span>
              <span class="copy-text">复制</span>
            </button>
          </div>
        </div>
        <p class="card-note">💡 API接口和JSON数据可通过程序直接调用</p>
      </div>

      <!-- 其他卡片 -->
      <div class="card card-metrics">
        <h3>📊 关键指标趋势</h3>
        <div class="metrics-grid">
          <div class="metric-item">
            <div class="metric-header">
              <span class="metric-label">📈 新增源 (7天)</span>
              <span class="metric-value" id="new-count-7">-</span>
            </div>
            <canvas id="spark-added-7" height="40"></canvas>
          </div>
          <div class="metric-item">
            <div class="metric-header">
              <span class="metric-label">📉 失效源 (7天)</span>
              <span class="metric-value" id="removed-count-7">-</span>
            </div>
            <canvas id="spark-removed-7" height="40"></canvas>
          </div>
          <div class="metric-item">
            <div class="metric-header">
              <span class="metric-label">💚 存活源 (30天)</span>
              <span class="metric-value" id="alive-count-30">-</span>
            </div>
            <canvas id="spark-alive-30" height="40"></canvas>
          </div>
        </div>
        
        <!-- 7天趋势详情图表 -->
        <div class="trend-details">
          <h4>📈 前七天详细趋势</h4>
          <div class="trend-chart-container">
            <canvas id="trend7day-chart" width="400" height="200"></canvas>
          </div>
          <div class="trend-legend">
            <div class="legend-item">
              <span class="legend-color" style="background: #10b981;"></span>
              <span class="legend-label">新增源 (Google + GitHub 发现)</span>
            </div>
            <div class="legend-item">
              <span class="legend-color" style="background: #ef4444;"></span>
              <span class="legend-label">失效源 (无法访问或已失效)</span>
            </div>
            <div class="legend-item">
              <span class="legend-color" style="background: #22c55e;"></span>
              <span class="legend-label">存活源 (当前可用源总数)</span>
            </div>
            <div class="legend-item">
              <span class="legend-color" style="background: #f59e0b;"></span>
              <span class="legend-label">净增长 (新增 - 失效)</span>
            </div>
          </div>
          <div class="trend-description">
            <p class="trend-desc-text">
              📊 <strong>图表说明</strong>：X轴为日期，Y轴为数量。
              <br>🟢 <strong>绿色线条</strong>：新增源（Google + GitHub 发现）
              <br>🔴 <strong>红色线条</strong>：失效源（无法访问或已失效）
              <br>🟢 <strong>深绿色线条</strong>：存活源（当前可用源总数）
              <br>🟠 <strong>橙色线条</strong>：净增长（新增 - 失效）
              <br>💡 数据来源于Google搜索和GitHub发现，实时更新。
            </p>
        </div>
      </div>
      </div>

      <div class="card card-recent">
        <h3>🆕 最新有效订阅源</h3>
        <div id="recent-urls">
          <div class="loading-placeholder">正在加载最新源...</div>
        </div>
      </div>

      <div class="card card-health">
        <h3>健康信息</h3>
        <ul class="health-list">
          <li>构建时间(中国时区)：<b>__TS_CN__</b></li>
          <li>下次更新时间(中国时区)：<b>__NEXT_CN__</b></li>
          <li>源：<b>__ALIVE__/__TOTAL__</b> · 新增 <b>__NEW__</b> · 移除 <b>__REMOVED__</b></li>
          <li>节点：<b>__NODES__</b> · 协议 SS <b>__SS__</b> | VMess <b>__VMESS__</b> | VLESS <b>__VLESS__</b> | Trojan <b>__TROJAN__</b> | HY2 <b>__HY2__</b></li>
          <li>来源：Google <b>__GCOUNT__</b> | GitHub <b>__GHCOUNT__</b> | Telegram <b>__TGCOUNT__</b></li>
        </ul>
        
        <!-- 标注式速度排行显示 -->
        <div id="speed-ranking-section" class="speed-ranking-section" style="display: none;">
          <h3>🚀 速度排行 (标注式)</h3>
          <div class="speed-disclaimer">
            <p><strong>⚠️ 重要说明：</strong>此测速基于云环境，不代表国内用户真实速度。建议用户自行测试验证。</p>
          </div>
          <div id="speed-ranking-list" class="speed-ranking-list">
            <!-- 动态加载标注式速度排行数据 -->
          </div>
        </div>
      </div>

      <div class="card card-serpapi">
        <h3>SerpAPI 密钥状态</h3>
        <div id="serpapi-status">
          <div class="serpapi-summary">
            <span class="status-item">可用密钥: <b id="keys-ok">__KOK__</b>/<b id="keys-total">__KTOTAL__</b></span>
            <span class="status-item">总剩余额度: <b id="quota-left">__QLEFT__</b>/<b id="quota-cap">__QCAP__</b></span>
          </div>
          <div id="serpapi-keys-list" class="serpapi-keys-list">
            <!-- 动态加载密钥详情 -->
          </div>
          <div style="margin-top: 1rem; text-align: center;">
            <a href="key_manager.html" class="btn-primary" style="display: inline-block; padding: 0.5rem 1rem; text-decoration: none;">
              🔑 管理 SerpAPI 密钥
            </a>
          </div>
        </div>
      </div>

      <div class="card card-protocols">
        <h3>协议分布</h3>
        <ul>
          <li>SS：__SS__</li>
          <li>VMess：__VMESS__</li>
          <li>VLESS：__VLESS__</li>
          <li>Trojan：__TROJAN__</li>
          <li>Hysteria2：__HY2__</li>
        </ul>
      </div>

      <div class="card card-wide card-details">
        <h3>源详细信息</h3>
        <p><small>包含机场名称、容量/剩余、协议、复制与测速、详情页。</small></p>
        <div id="url-meta"><small>加载中...</small></div>
        <div class="chart">
          <h4 style="margin:0 0 8px 0">每日新增可用URL</h4>
          <canvas id="dailyChart" height="120"></canvas>
        </div>
        <script>
          function copyText(text){
            navigator.clipboard.writeText(text).then(()=>{
              alert('已复制订阅链接');
            }).catch(()=>{});
          }
          function copyFileUrl(path, btn){
            const fullUrl = window.location.origin + window.location.pathname.replace(/\/[^\/]*$/, '/') + path;
            navigator.clipboard.writeText(fullUrl).then(()=>{
              // 临时改变按钮文本和样式
              const originalText = btn.textContent;
              btn.textContent = '✓ 已复制';
              btn.style.background = '#10b981';
              btn.style.borderColor = '#10b981';
              btn.style.color = 'white';
              
              setTimeout(() => {
                btn.textContent = originalText;
                btn.style.background = '#1f2937';
                btn.style.borderColor = '#374151';
                btn.style.color = '#9ca3af';
              }, 1500);
            }).catch(()=>{
              alert('复制失败，请手动复制: ' + fullUrl);
            });
          }
          async function testSpeed(url){
            const t0 = performance.now();
            try{ await fetch(url, {method:'HEAD', mode:'no-cors'}); }catch(e){}
            const t1 = performance.now();
            return Math.round(t1 - t0);
          }
          async function runBatchSpeed(urls, concurrency){
            const results = new Array(urls.length).fill(null);
            let idx = 0;
            async function worker(){
              while(idx < urls.length){
                const i = idx++;
                const u = urls[i];
                const ms = await testSpeed(u);
                results[i] = ms;
                const cell = document.querySelector(`[data-url-id="${i}"]`);
                if(cell){
                  cell.textContent = ms;
                  cell.style.color = ms<=300?'#10b981':(ms<=800?'#60a5fa':'#f59e0b');
                }
              }
            }
            const workers = Array.from({length: Math.min(concurrency, urls.length)}, ()=>worker());
            await Promise.all(workers.map(w=>w()));
            return results;
          }
          async function loadMeta() {
            try {
              const res = await fetch('sub/url_meta.json', { cache: 'no-cache' });
              if (!res.ok) throw new Error('fetch failed');
              let data = await res.json();
              // 只展示可用源
              data = (Array.isArray(data) ? data : []).filter(x=>x && x.available);
              // 按质量分倒序排序
              data.sort((a,b)=> (b.quality_score||0) - (a.quality_score||0));
              const rows = data.map(function(item, i){
                const q = (item.quality_score ?? 0);
                const qColor = q>=80?'#10b981':(q>=60?'#60a5fa':'#f59e0b');
                const src = (item.source||'').toLowerCase();
                const pillColor = src==='github'?'#111827':(src==='telegram'?'#1d4ed8':'#0b1220');
                const pillText = src==='github'?'GitHub':(src==='telegram'?'Telegram':'Google');
                return '<tr>' +
                  '<td><div style="display:flex;gap:8px;align-items:center">' +
                    '<a href="' + (item.url||'#') + '" target="_blank">源</a>' +
                    '<small style="color:#94a3b8">' + (item.provider||item.host||'') + '</small>' +
                  '</div></td>' +
                  '<td>' + (item.available ? '✅' : '❌') + '</td>' +
                  '<td>' + (item.nodes_total ?? 0) + '</td>' +
                  '<td>' + (item.protocols ?? '') + '</td>' +
                  '<td>' + ((item.traffic?.remaining ?? '-') + ' / ' + (item.traffic?.total ?? '-') + ' ' + (item.traffic?.unit ?? '')) + '</td>' +
                  '<td data-url-id="' + i + '">' + (item.response_ms ?? '-') + '</td>' +
                  '<td><b style="color:' + qColor + '">' + q + '</b></td>' +
                  '<td><span class="pill" style="background:' + pillColor + '">' + pillText + '</span></td>' +
                  '<td>' + (item.first_seen || '-') + '</td>' +
                  '<td>' +
                    '<button onclick="copyText(\'' + (item.url||'') + '\')" style="padding:4px 8px;border-radius:8px;border:1px solid #1f2937;background:#0b1220;color:#e5e7eb">复制</button>' +
                    '<button class="btn-speed" data-url="' + (item.url||'') + '" style="margin-left:6px;padding:4px 8px;border-radius:8px;border:1px solid #1f2937;background:#0b1220;color:#e5e7eb">测速</button>' +
                    (item.detail_page ? '<a href="' + item.detail_page + '" style="margin-left:8px">详情</a>' : '') +
                  '</td>' +
                '</tr>';
              }).join('');
              const html = '<table>' +
                '<thead><tr>' +
                '<th style="text-align:left">URL/机场</th>' +
                '<th>可用</th>' +
                '<th>节点数</th>' +
                '<th>协议</th>' +
                '<th>流量(剩余/总量)</th>' +
                '<th>耗时(ms)</th>' +
                '<th>质量</th>' +
                '<th>来源</th>' +
                '<th>采集</th>' +
                '<th>操作</th>' +
                '</tr></thead>' +
                '<tbody>' + rows + '</tbody>' +
                '</table>';
              document.getElementById('url-meta').innerHTML = html;
              // 绑定单击测速
              document.querySelectorAll('.btn-speed').forEach(btn=>{
                btn.addEventListener('click', async (e)=>{
                  const u = e.currentTarget.getAttribute('data-url');
                  const ms = await testSpeed(u);
                  e.currentTarget.closest('tr').querySelector('[data-url-id]').textContent = ms;
                });
              });
              // 批量测速（限并发 6）
              const urls = data.map(x=>x.url);
              runBatchSpeed(urls, 6);
            } catch(e) {
              document.getElementById('url-meta').innerHTML = '<small>未获取到源详情</small>';
            }
          }
          async function loadDailyChart() {
            try {
              const r = await fetch('sub/stats_daily.json', { cache:'no-cache' });
              if (!r.ok) return;
              const d = await r.json();
              const labels = d.map(x=>x.date);
              const google = d.map(x=>x.google_added||0);
              const github = d.map(x=>x.github_added||0);
              const telegram = d.map(x=>x.telegram_added||0);
              const added = d.map(x=>x.new_total||0);
              const removed = d.map(x=>x.removed_total||0);
              const canvas = document.getElementById('dailyChart');
              const ctx = canvas.getContext('2d');
              // 极简绘制
              const max = Math.max(1, ...google, ...github, ...telegram, ...added, ...removed);
              const W = canvas.width = canvas.clientWidth;
              const H = canvas.height;
              function plot(series, color, yoff) {
                ctx.strokeStyle=color; ctx.lineWidth=2; ctx.beginPath();
                series.forEach((v,i)=>{
                  const x = (W-20) * (i/(series.length-1)) + 10;
                  const y = H-10 - (H-20) * (v/max);
                  if (i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
                }); ctx.stroke();
              }
              ctx.clearRect(0,0,W,H); ctx.fillStyle='#0b1220'; ctx.fillRect(0,0,W,H);
              plot(google,'#60a5fa'); plot(github,'#10b981'); plot(telegram,'#38bdf8'); plot(added,'#a78bfa'); plot(removed,'#f87171');
            } catch(e) {}
          }
          function drawSparkline(canvasId, series, color){
            const c = document.getElementById(canvasId); if(!c) return; const ctx=c.getContext('2d');
            const W = c.width = c.clientWidth || 160; const H = c.height; const max = Math.max(1, ...series);
            ctx.clearRect(0,0,W,H); ctx.strokeStyle=color; ctx.lineWidth=2; ctx.beginPath();
            series.forEach((v,i)=>{ const x=(W-6)*(i/(series.length-1))+3; const y=H-3 - (H-6)*(v/max); if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y); });
            ctx.stroke();
          }
          async function loadSparklines(){
            try{
              const r = await fetch('sub/stats_daily.json', { cache:'no-cache' }); if(!r.ok) return;
              const d = await r.json();
              const last7 = d.slice(-7);
              const last30 = d.slice(-30);
              
              // 更新指标数值
              const newCount7 = last7.reduce((sum, x) => sum + (x.new_total||0), 0);
              const removedCount7 = last7.reduce((sum, x) => sum + (x.removed_total||0), 0);
              const aliveCount30 = last30.length > 0 ? last30[last30.length-1].alive_total||0 : 0;
              
              document.getElementById('new-count-7').textContent = newCount7;
              document.getElementById('removed-count-7').textContent = removedCount7;
              document.getElementById('alive-count-30').textContent = aliveCount30;
              
              drawSparkline('spark-added-7', last7.map(x=>x.new_total||0), '#60a5fa');
              drawSparkline('spark-removed-7', last7.map(x=>x.removed_total||0), '#f87171');
              drawSparkline('spark-alive-30', last30.map(x=>x.alive_total||0), '#10b981');
            }catch(e){}
          }

          // 加载最新有效URL
          async function loadRecentUrls() {
            try {
              const res = await fetch('sub/url_meta.json', { cache: 'no-cache' });
              if (!res.ok) throw new Error('fetch failed');
              let data = await res.json();
              
              // 筛选最新的有效源
              data = (Array.isArray(data) ? data : []).filter(x=>x && x.available);
              
              // 按质量分和日期排序，取前5个
              data.sort((a,b)=> {
                const scoreA = (b.quality_score||0) - (a.quality_score||0);
                if (scoreA !== 0) return scoreA;
                return new Date(b.first_seen||'1970-01-01') - new Date(a.first_seen||'1970-01-01');
              });
              
              const recentData = data.slice(0, 5);
              const container = document.getElementById('recent-urls');
              
              if (recentData.length === 0) {
                container.innerHTML = '<div class="no-data">暂无最新源</div>';
                return;
              }
              
              container.innerHTML = recentData.map(item => {
                const host = item.host || new URL(item.url).hostname;
                const traffic = item.traffic || {};
                const remaining = traffic.remaining || '-';
                const total = traffic.total || '-';
                const unit = traffic.unit || '';
                const quality = item.quality_score || 0;
                const qualityColor = quality >= 80 ? '#10b981' : quality >= 60 ? '#60a5fa' : '#f59e0b';
                
                return `
                  <div class="recent-url-item">
                    <div class="url-header">
                      <div class="url-title">
                        <a href="${item.url}" target="_blank" class="url-link">${host}</a>
                        <span class="quality-score" style="color: ${qualityColor}">质量: ${quality}</span>
                      </div>
                      <div class="url-actions">
                        <button onclick="copyText('${item.url}')" class="copy-btn-mini">复制链接</button>
                      </div>
                    </div>
                    <div class="url-stats">
                      <span class="stat-item">📊 ${item.nodes_total || 0} 节点</span>
                      <span class="stat-item">💾 ${remaining}/${total} ${unit}</span>
                      <span class="stat-item">📅 ${item.first_seen || '-'} ${item.first_seen_time || ''}</span>
                    </div>
                  </div>
                `;
              }).join('');
              
            } catch(e) {
              document.getElementById('recent-urls').innerHTML = '<div class="error-msg">加载失败</div>';
            }
          }

          // 加载 SerpAPI 密钥详情
          async function loadSerpAPIKeys() {
            console.log('🔑 开始加载SerpAPI密钥详情...');
            try {
              const r = await fetch('health.json', { cache:'no-cache' });
              if(!r.ok) {
                console.error('❌ 获取health.json失败:', r.status);
                return;
              }
              const health = await r.json();
              console.log('📊 获取到health数据:', health);
              const keys = health.serpapi_keys_detail || [];
              console.log('🔑 密钥详情:', keys);
              const container = document.getElementById('serpapi-keys-list');
              if(!container) {
                console.error('❌ 找不到serpapi-keys-list容器');
                return;
              }
              
              if(keys.length === 0) {
                console.log('⚠️ 没有密钥信息');
                container.innerHTML = '<div class="serpapi-key-item error">暂无密钥信息</div>';
                return;
              }
              
              container.innerHTML = keys.map(key => {
                if(key.error) {
                  return `<div class="serpapi-key-item error">
                    <div class="key-header">
                      <span class="key-index">密钥 ${key.index}</span>
                      <span class="key-status">错误</span>
                    </div>
                    <div class="key-details">
                      <div style="color:#ef4444">${key.error}</div>
                      ${key.status === 'key_valid_unchecked' ? '<div style="color:#10b981;margin-top:4px">✓ 密钥格式有效，但无法检查配额</div>' : ''}
                      ${key.status === 'key_invalid' ? '<div style="color:#ef4444;margin-top:4px">✗ 密钥格式无效</div>' : ''}
                      ${key.registration_date ? `<div class="registration-info" style="margin-top:4px">注册日期: ${key.registration_date}</div>` : ''}
                    </div>
                  </div>`;
                }
                const used = key.used_searches || 0;
                const total = key.searches_per_month || 0;
                const left = key.total_searches_left || 0;
                const usagePercent = total > 0 ? Math.round((used / total) * 100) : 0;
                const statusClass = left <= 0 ? 'exhausted' : (usagePercent > 80 ? 'warning' : 'ok');
                const resetDate = key.reset_date ? new Date(key.reset_date).toLocaleDateString('zh-CN') : '未知';
                
                return `
                  <div class="serpapi-key-item ${statusClass}">
                    <div class="key-header">
                      <span class="key-index">密钥 ${key.index}</span>
                      <span class="key-status">${left <= 0 ? '已用尽' : (usagePercent > 80 ? '即将用尽' : '正常')}</span>
                    </div>
                    <div class="key-details">
                      <div class="quota-bar">
                        <div class="quota-fill" style="width: ${usagePercent}%"></div>
                      </div>
                      <div class="quota-text">已用 ${used}/${total} (${usagePercent}%) · 剩余 ${left}</div>
                      <div class="reset-info">重置时间: ${resetDate}</div>
                      ${key.registration_date ? `<div class="registration-info">注册日期: ${key.registration_date}</div>` : ''}
                    </div>
                  </div>
                `;
              }).join('');
              console.log('✅ SerpAPI密钥详情加载完成');
            } catch(e) { 
              console.error('❌ SerpAPI keys load failed:', e);
              const container = document.getElementById('serpapi-keys-list');
              if(container) container.innerHTML = '<div class="serpapi-key-item error">加载失败</div>';
            }
          }
          
          async function loadTrend7Day() {
            try {
              const r = await fetch('sub/stats_7day_enhanced.json', { cache:'no-cache' });
              if (!r.ok) {
                document.getElementById('trend7day-chart').style.display = 'none';
                return;
              }
              const data = await r.json();
              
              if (!data || data.length === 0) {
                document.getElementById('trend7day-chart').style.display = 'none';
                return;
              }
              
              // 绘制7天趋势图表
              const canvas = document.getElementById('trend7day-chart');
              if (!canvas) return;
              
              const ctx = canvas.getContext('2d');
              const W = canvas.width = canvas.clientWidth || 400;
              const H = canvas.height = 200;
              
              // 准备数据
              const dates = data.map(d => d.date || '');
              const newAdded = data.map(d => d.new_added || 0);
              const failed = data.map(d => d.failed_count || 0);
              const alive = data.map(d => d.alive_count || 0);
              const netGrowth = data.map(d => d.net_growth || 0);
              
              // 计算最大值用于缩放
              const maxValue = Math.max(1, ...newAdded, ...failed, ...alive, ...netGrowth);
              
              // 清空画布
              ctx.clearRect(0, 0, W, H);
              ctx.fillStyle = '#0b1220';
              ctx.fillRect(0, 0, W, H);
              
              // 绘制网格线
              ctx.strokeStyle = '#334155';
              ctx.lineWidth = 1;
              for (let i = 0; i <= 4; i++) {
                const y = 20 + (H - 40) * (i / 4);
                ctx.beginPath();
                ctx.moveTo(40, y);
                ctx.lineTo(W - 20, y);
                ctx.stroke();
              }
              
              // 绘制数据线
              function drawLine(series, color, lineWidth = 2) {
                ctx.strokeStyle = color;
                ctx.lineWidth = lineWidth;
                ctx.beginPath();
                series.forEach((value, i) => {
                  const x = 40 + (W - 60) * (i / (series.length - 1));
                  const y = H - 20 - (H - 40) * (value / maxValue);
                  if (i === 0) {
                    ctx.moveTo(x, y);
                  } else {
                    ctx.lineTo(x, y);
                  }
                });
                ctx.stroke();
              }
              
              // 绘制各条趋势线
              drawLine(newAdded, '#10b981', 3);  // 新增源 - 绿色
              drawLine(failed, '#ef4444', 2);    // 失效源 - 红色
              drawLine(alive, '#22c55e', 2);     // 存活源 - 绿色
              drawLine(netGrowth, '#f59e0b', 2); // 净增长 - 橙色
              
              // 绘制数据点
              function drawPoints(series, color) {
                ctx.fillStyle = color;
                series.forEach((value, i) => {
                  const x = 40 + (W - 60) * (i / (series.length - 1));
                  const y = H - 20 - (H - 40) * (value / maxValue);
                  ctx.beginPath();
                  ctx.arc(x, y, 3, 0, 2 * Math.PI);
                  ctx.fill();
                });
              }
              
              drawPoints(newAdded, '#10b981');
              drawPoints(failed, '#ef4444');
              drawPoints(alive, '#22c55e');
              drawPoints(netGrowth, '#f59e0b');
              
              // 绘制X轴标签（日期）
              ctx.fillStyle = '#94a3b8';
              ctx.font = '11px ui-sans-serif';
              ctx.textAlign = 'center';
              dates.forEach((date, i) => {
                const x = 40 + (W - 60) * (i / (dates.length - 1));
                ctx.fillText(date, x, H - 5);
              });
              
              // 绘制Y轴标签（从下到上，数值递增）
              ctx.textAlign = 'right';
              ctx.fillStyle = '#94a3b8';
              ctx.font = '11px ui-sans-serif';
              for (let i = 0; i <= 4; i++) {
                const value = Math.round(maxValue * (i / 4));
                const y = H - 20 - (H - 40) * (i / 4); // 修正Y坐标计算
                ctx.fillText(value.toString(), 35, y + 4);
              }
              
              // 添加Y轴标题
              ctx.save();
              ctx.translate(15, H / 2);
              ctx.rotate(-Math.PI / 2);
              ctx.textAlign = 'center';
              ctx.fillText('数量', 0, 0);
              ctx.restore();
              
            } catch(e) {
              console.warn('7天趋势图表加载失败:', e);
              const canvas = document.getElementById('trend7day-chart');
              if (canvas) canvas.style.display = 'none';
            }
          }
          
          // 确保所有函数都正确定义后再调用
        setTimeout(() => {
          console.log('🚀 开始加载所有内容...');
          if (typeof loadMeta === 'function') loadMeta();
          if (typeof loadDailyChart === 'function') loadDailyChart();
          if (typeof loadSparklines === 'function') loadSparklines();
          if (typeof loadSerpAPIKeys === 'function') {
            console.log('🔑 调用loadSerpAPIKeys函数');
            loadSerpAPIKeys();
          } else {
            console.error('❌ loadSerpAPIKeys函数未定义');
          }
          if (typeof loadRecentUrls === 'function') loadRecentUrls();
          if (typeof loadTrend7Day === 'function') loadTrend7Day();
          if (typeof loadSpeedRanking === 'function') {
            console.log('🚀 调用loadSpeedRanking函数');
            loadSpeedRanking();
          } else {
            console.error('❌ loadSpeedRanking函数未定义');
          }
          console.log('✅ 所有内容加载函数调用完成');
        }, 100);
        
        async function loadSpeedRanking() {
          console.log('🚀 开始加载标注式速度排行数据...');
          try {
            const response = await fetch('data/speed_ranking.json', { cache: 'no-cache' });
            if (!response.ok) {
              throw new Error('HTTP ' + response.status);
            }
            const data = await response.json();
            console.log('📊 获取到标注式速度排行数据:', data);
            
            const ranking = data.ranking || [];
            const section = document.getElementById('speed-ranking-section');
            const container = document.getElementById('speed-ranking-list');
            
            if (!section || !container) {
              console.error('❌ 找不到速度排行容器');
              return;
            }
            
            if (ranking.length === 0) {
              section.style.display = 'none';
              return;
            }
            
            // 显示速度排行区域
            section.style.display = 'block';
            
            let html = '';
            ranking.slice(0, 10).forEach((node, index) => {
              const score = node.scores ? node.scores.total_score.toFixed(1) : 'N/A';
              const location = node.location || '未知';
              const protocol = node.protocol || '未知';
              const annotations = node.annotations || {};
              const cloudLatency = annotations.cloud_latency || 'N/A';
              const chinaEstimate = annotations.china_estimate || 'N/A';
              const confidence = annotations.confidence || '低';
              const note = annotations.note || '';
              
              const confidenceClass = confidence === '高' ? 'high' : confidence === '中' ? 'medium' : 'low';
              
              html += `
                <div class="speed-ranking-item annotated">
                  <div class="ranking-number">${node.rank || (index + 1)}</div>
                  <div class="ranking-info">
                    <div class="ranking-score">${score}分</div>
                    <div class="ranking-location">${location}</div>
                    <div class="ranking-protocol">${protocol}</div>
                  </div>
                  <div class="ranking-details">
                    <div class="latency-info">
                      <span class="cloud-latency">云延迟: ${cloudLatency}</span>
                      <span class="china-estimate">国内估算: ${chinaEstimate}</span>
                    </div>
                    <div class="confidence-info">
                      <span class="confidence ${confidenceClass}">置信度: ${confidence}</span>
                    </div>
                    <div class="note-info">${note}</div>
                  </div>
                </div>
              `;
            });
            
            container.innerHTML = html;
            console.log('✅ 标注式速度排行数据加载完成');
          } catch (error) {
            console.error('❌ 加载标注式速度排行数据失败:', error);
            const section = document.getElementById('speed-ranking-section');
            if (section) {
              section.style.display = 'none';
            }
          }
        }
        </script>
      </div>
    </div>

    <p><small>仅展示可用源（自动过滤失效/超额/限速来源）。 构建(UTC)：__TS__ · 下次(UTC)：__NEXT__</small></p>
  </div>
</body>
</html>
