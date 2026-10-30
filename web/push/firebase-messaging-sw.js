// Configuración pública por entorno en la URL del worker. Sin credenciales de servidor.
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.stopImmediatePropagation();
  event.waitUntil((async () => {
    const data = event.notification.data;
    const windows = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    for (const client of windows) {
      if (await bindingOf(client) === data?.registrationId) {
        await client.focus();
        client.postMessage({type: 'CROWDRADAR_OPEN', data});
        return;
      }
    }
  })());
});
function bindingOf(client) {
  return new Promise(resolve => {
    const channel = new MessageChannel();
    const timeout = setTimeout(() => resolve(''), 1000);
    channel.port1.onmessage = event => { clearTimeout(timeout); resolve(event.data); channel.port1.close(); };
    client.postMessage({type: 'CROWDRADAR_BINDING'}, [channel.port2]);
  });
}
importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js');
const config = Object.fromEntries(new URL(self.location.href).searchParams);
firebase.initializeApp(config);
firebase.messaging().onBackgroundMessage(async message => {
  const data = message.data;
  if (!data?.registrationId || !data?.userId || !data?.placeId) return;
  const windows = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
  for (const client of windows) {
    if (await bindingOf(client) === data.registrationId) {
      await self.registration.showNotification('Cambió la saturación de un favorito', {
        body: 'Abre CrowdRadar para consultar el lugar.', data, tag: `favorite-${data.placeId}`
      });
      return;
    }
  }
});
