const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('flightAPI', {
  getState:        ()         => ipcRenderer.invoke('get-state'),
  loadSimBrief:    ()         => ipcRenderer.invoke('load-simbrief'),
  getSettings:     ()         => ipcRenderer.invoke('get-settings'),
  saveSettings:    (settings) => ipcRenderer.invoke('save-settings', settings),
  getTraffic:      ()         => ipcRenderer.invoke('get-traffic'),
  onStateUpdate:   (cb) => { ipcRenderer.on('flight-state',    (_, d) => cb(d)); },
  onTrafficUpdate: (cb) => { ipcRenderer.on('traffic-update',  (_, d) => cb(d)); },
});
