// 自己破壊型 Service Worker。
// このアプリはService Workerによるキャッシュを使わない方針にしたため、
// 過去にインストールされた（Flutterデフォルトの）Service Workerが残っている
// 端末でも、この内容に置き換わった時点で即座に自身を無効化し、
// 開いているタブを再読み込みさせて最新版へ強制的に切り替える。
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', async (event) => {
  const keys = await caches.keys();
  await Promise.all(keys.map((k) => caches.delete(k)));
  await self.registration.unregister();
  const clientsArr = await self.clients.matchAll({ type: 'window' });
  clientsArr.forEach((c) => c.navigate(c.url));
});
