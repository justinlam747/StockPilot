// Run immediately — script is at bottom of body, DOM is ready
(function() {
  var btn = document.getElementById('get-started-btn');
  if (!btn) return;

  var isDev = document.body.dataset.env === 'development';

  btn.addEventListener('click', function(e) {
    e.preventDefault();
    if (isDev) {
      window.location.href = '/dev/login';
      return;
    }

    // Production: load Clerk on demand
    var key = document.querySelector('meta[name="clerk-key"]');
    if (!key || !key.content) return;

    var script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/@clerk/clerk-js@5/dist/clerk.browser.js';
    script.crossOrigin = 'anonymous';
    script.onload = async function() {
      await Clerk.load({ publishableKey: key.content });
      if (Clerk.user) {
        window.location.href = '/onboarding';
      } else {
        Clerk.openSignUp({ redirectUrl: '/onboarding' });
      }
    };
    document.head.appendChild(script);
  });
})();
