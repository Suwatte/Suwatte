_network = new NetworkHandler();

class NetworkError extends Error {
  req;
  res;
  constructor(name, message, req, res) {
    super(message);
    this.name = name;
    this.message = message;
    this.req = req;
    this.res = res;
  }
}

class CloudflareError extends Error {
  constructor() {
    super("The requested resource is cloudflare protected");
    this.name = "CloudflareError";
  }
}

class NetworkClient {
  transformRequest;
  transformResponse;
  async get(url, config) {
    return this.request({ url, method: "GET", ...config });
  }
  async post(url, config) {
    return this.request({ url, method: "POST", ...config });
  }
  async request(request) {
    const factory = async (r, methods) => {
      for (const m of methods) {
        r = await m(r);
      }
      return r;
    };

    //  Request Transform
    const reqTransformers = [];
    if (this.transformRequest) {
      if (typeof this.transformRequest === "function")
        reqTransformers.push(this.transformRequest);
      else reqTransformers.push(...this.transformRequest);
    }

    if (request.transformRequest) {
      if (typeof request.transformRequest === "function")
        reqTransformers.push(request.transformRequest);
      else reqTransformers.push(...request.transformRequest);
    }

    // Response Transform
    const resTransformers = [];
    if (this.transformResponse) {
      if (typeof this.transformResponse === "function")
        resTransformers.push(this.transformResponse);
      else resTransformers.push(...this.transformResponse);
    }

    if (request.transformResponse) {
      if (typeof request.transformResponse === "function")
        resTransformers.push(request.transformResponse);
      else resTransformers.push(...request.transformResponse);
    }

    // Run Request Transformers
    request = await factory(request, reqTransformers);

    // Dispatch
    let response = await _network.post(request);

    // Run Response Transformers
    response = await factory(response, resTransformers);

    // Validate Status
    const defaultValidateStatus = (s) => s >= 200 && s < 300;
    const validateStatus = request.validateStatus ?? defaultValidateStatus;

    if (!validateStatus(response.status)) {
      if (
        [503, 403].includes(response.status) &&
        response.headers["Server"] === "cloudflare"
      )
        throw new CloudflareError();

      const error = new NetworkError(
        "NetworkError",
        `Request failed with status ${response.status}`,
        request,
        response
      );
      switch (response.status) {
        case 400:
          error.message = "Bad Request";
          break;
        case 401:
          error.message = "Unauthorized";
          break;
        case 403:
          error.message = "Forbidden";
          break;
        case 404:
          error.message =
            "Not Found.\nThe server cannot find the requested resource.";
          break;
        case 405:
          error.message =
            "Method Not Allowed\nThe request method is known by the server but is not supported by the target resource.";
          break;
        case 410:
          error.message = "Gone.";
          break;
        case 429:
          error.message = "Too Many Requests.";
          break;
        case 431:
          error.message =
            "Request Header Fields Too Large.\nThe server is unwilling to process the request because its header fields are too large. ";
          break;
        case 500:
          error.message =
            "Internal Server Error.\nThe server has encountered a situation it does not know how to handle.";
          break;
        case 501:
          error.message =
            "Not Implemented\nThe request method is not supported by the server and cannot be handled.";
          break;
        case 502:
          error.message =
            "Bad Gateway\nThis error response means that the server, while working as a gateway to get a response needed to handle the request, got an invalid response.";
          break;
        case 503:
          error.message =
            "Service Unavailable.The server is not ready to handle the request. Common causes are a server that is down for maintenance or that is overloaded.";
          break;
        case 504:
          error.message =
            "Gateway Timeout\nThis error response is given when the server is acting as a gateway and cannot get a response in time.";
          break;
      }

      throw error;
    }

    return {
      ...response,
      request: request,
    };
  }
}
