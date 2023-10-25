_store = new StoreHandler();

/**
 * STT STore Implementation
 */

class STTStore {
  constructor(store) {
    this.store = store;
  }
  store;
  async get(key) {
    const str = await _store.post({
      store: this.store,
      action: "get",
      key,
        id: IDENTIFIER
    });
    if (!str) return null;
    return JSON.parse(str);
  }
  async set(key, value) {
    await _store.post({
      store: this.store,
      action: "set",
      key,
      value: JSON.stringify(value),
    id: IDENTIFIER

    });
    return;
  }
  async remove(key) {
    await _store.post({
      store: this.store,
      action: "remove",
      key,
    id: IDENTIFIER

    });
    return;
  }

  async string(key) {
    const value = await this.get(key);
    if (!value) return null;

    if (typeof value !== "string")
      throw new Error(
        "ObjectStore Type Assertion failed, value is not a string"
      );
    return value;
  }
  async boolean(key) {
    const value = await this.get(key);
    if (!value) return null;

    if (typeof value !== "boolean")
      throw new Error(
        "ObjectStore Type Assertion failed, value is not a boolean"
      );
    return value;
  }
  async number(key) {
    const value = await this.get(key);
    if (!value) return null;

    if (typeof value !== "number")
      throw new Error("ObjectStore Type Assertion failed, value is not number");
    return value;
  }

  async stringArray(key) {
    const value = await this.get(key);
    if (!value) return null;

    if (typeof value !== "object" || !Array.isArray(value))
      throw new Error(
        "ObjectStore type assertion failed, value is not an array"
      );

    if (!value?.[0]) return value; // Return If Empty

    const isValid = value.every((v) => typeof v === "string");
    if (!isValid)
      throw new Error(
        `ObjectStore Type Assertion Failed, Elements of Array are not of type string`
      );
    return value;
  }
}


const ObjectStore = new STTStore("os");
const SecureStore = new STTStore("ss");
