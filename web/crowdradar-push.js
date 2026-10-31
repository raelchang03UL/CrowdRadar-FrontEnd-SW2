// Solo binding efímero. No JWT, almacenamiento ni inicio automático de sesión.
(() => {
  let currentBinding = () => '';
  let openPlace = () => {};
  window.crowdRadarPush = {
    initialize(binding, open) { currentBinding = binding; openPlace = open; },
    // Migración de compatibilidad acotada al esquema Firebase JS13.1.0 del lock.
    // Solo cuenta la entrada del appId actual; nunca lee FID, token o auth.
    async hasFidRegistration(appId) {
      if (!appId || typeof globalThis.indexedDB?.databases !== 'function') throw new Error('Messaging storage unavailable');
      const databases = await indexedDB.databases();
      if (!databases.some(database => database.name === 'firebase-messaging-database')) return false;
      return new Promise((resolve, reject) => {
        const request = indexedDB.open('firebase-messaging-database');
        request.onupgradeneeded = () => request.transaction.abort();
        request.onerror = request.onblocked = () => reject(new Error('Messaging storage unavailable'));
        request.onsuccess = () => {
          const database = request.result;
          const store = 'firebase-messaging-fid-registration-store';
          if (!database.objectStoreNames.contains(store)) { database.close(); resolve(false); return; }
          const transaction = database.transaction(store, 'readonly');
          const count = transaction.objectStore(store).count(appId);
          let present = false;
          count.onsuccess = () => { present = count.result > 0; };
          transaction.oncomplete = () => { database.close(); resolve(present); };
          transaction.onerror = transaction.onabort = () => { database.close(); reject(new Error('Messaging storage unavailable')); };
        };
      });
    },
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
