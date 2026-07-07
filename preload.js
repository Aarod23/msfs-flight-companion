const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('flightAPI', {
  getState: () => ipcRenderer.invoke('get-state'),
  loadSimBrief: () => ipcRenderer.invoke('load-simbrief'),
  getSettings: () => ipcRenderer.invoke('get-settings'),
  saveSettings: (settings) => ipcRenderer.invoke('save-settings', settings),
  onStateUpdate: (callback) => {
    ipcRenderer.on('flight-state', (_, state) => callback(state));
  }
});
