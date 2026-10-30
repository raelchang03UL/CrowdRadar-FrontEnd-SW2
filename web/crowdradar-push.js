// Solo binding efímero. No JWT, almacenamiento ni inicio automático de sesión.
(() => {
  let currentBinding = () => '';
  let openPlace = () => {};
  window.crowdRadarPush = {
    initialize(binding, open) { currentBinding = binding; openPlace = open; },
    async prepare(path) {
      const registration = await navigator.serviceWorker.register(path);
      if (registration.active) return;
      const worker = registration.installing || registration.waiting;
      if (!worker) throw new Error('No messaging worker');
      await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('Messaging worker timeout')), 15000);
        worker.addEventListener('statechange', () => {
          if (worker.state === 'activated') { clearTimeout(timeout); resolve(); }
          if (worker.state === 'redundant') { clearTimeout(timeout); reject(new Error('Messaging worker inactive')); }
        });
      });
    },
    clear() {
      if (!('serviceWorker' in navigator)) return;
      navigator.serviceWorker.getRegistrations().then(registrations => {
        const scope = new URL('push/', document.baseURI).href;
        for (const registration of registrations) {
          if (registration.scope === scope) registration.getNotifications().then(items => items.forEach(item => item.close()));
        }
      });
    }
  };
  if ('serviceWorker' in navigator) navigator.serviceWorker.addEventListener('message', event => {
    if (event.data?.type === 'CROWDRADAR_BINDING') event.ports[0]?.postMessage(currentBinding());
    if (event.data?.type === 'CROWDRADAR_OPEN') openPlace(JSON.stringify(event.data.data));
  });
})();
