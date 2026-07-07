const axios = require('axios');

class RelayClient {
  constructor(baseUrl, apiKey) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey;
    this.pushInterval = null;
    this.lastState = null;
  }

  async push(state) {
    try {
      await axios.post(`${this.baseUrl}/state`, state, {
        headers: {
          'x-api-key': this.apiKey,
          'Content-Type': 'application/json'
        },
        timeout: 5000
      });
    } catch (err) {
      // Silently fail — relay is optional
    }
  }

  async registerDevice(pushToken) {
    try {
      await axios.post(`${this.baseUrl}/register`, { pushToken }, {
        headers: { 'x-api-key': this.apiKey },
        timeout: 5000
      });
    } catch (err) {
      console.error('[Relay] Register failed:', err.message);
    }
  }
}

module.exports = RelayClient;
