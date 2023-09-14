class StoreHandler {
  post(val) {
    return window.webkit.messageHandlers.store.postMessage(val);
  }
}

class LogHandler {
  post(val) {
    window.webkit.messageHandlers.logging.postMessage(val);
  }
}

class NetworkHandler {
  post(val) {
    return window.webkit.messageHandlers.networking.postMessage(JSON.parse(JSON.stringify(val)));
  }
}


IDENTIFIER = "ID_PLACEHOLDER"
