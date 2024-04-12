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
  resolutionURL;
  constructor(resolutionURL) {
    super("The requested resource is cloudflare protected");
    this.name = "CloudflareError";
    this.resolutionURL = resolutionURL
  }
}

class NetworkClient {
  // Transformers
  requestTransformers = [];
  responseTransformers = [];
  headers = {};
  cookies = [];
  timeout;
  statusValidator;
  authorizationToken;
  maxRetries;
  // Rate Limiting
  buffer = [];
  lastRequestTime = 0;
  requestsPerSecond = 999;

  constructor(builder) {
    if (builder) {
      this.requestTransformers = builder.requestTransformers;
      this.responseTransformers = builder.responseTransformers;
      this.headers = builder.headers;
      this.cookies = builder.cookies;
      this.timeout = builder.timeout;
      this.statusValidator = builder.statusValidator;
      this.authorizationToken = builder.authorizationToken;
      this.maxRetries = builder.maxRetries;
      this.requestsPerSecond = builder.requestsPerSecond;
    }
  }

  combine(request) {
    //  Request Transform
    const RTX = [...this.requestTransformers];
    if (request.transformRequest) {
      if (typeof request.transformRequest === "function")
        RTX.push(request.transformRequest);
      else RTX.push(...request.transformRequest);
    }

    // Response Transform
    const RTS = [...this.responseTransformers];
    if (request.transformResponse) {
      if (typeof request.transformResponse === "function")
        RTS.push(request.transformResponse);
      else RTS.push(...request.transformResponse);
    }

    const headers = {
      ...this.headers,
      ...request.headers,
    };

    const cookies = [...this.cookies, ...(request.cookies ?? [])];

    const final = {
      headers,
      cookies,
      url: request.url,
      method: request.method ?? "GET",
      params: request.params,
      body: request.body,
      timeout: request.timeout ?? this.timeout,
      maxRetries: request.maxRetries ?? this.maxRetries,
      transformRequest: RTX,
      transformResponse: RTS,
      validateStatus: request.validateStatus ?? this.statusValidator,
    };

    return final;
  }
  async get(url, config) {
      return this.request({ url, method: "GET", ...config });
  }

  async post(url, config) {
    return this.request({ url, method: "POST", ...config });
  }
  async request(request) {
    // Mesh with Client Properties
    request = this.combine(request);
      
    // Run Request Transformers
    request = await this.factory(request, request.transformRequest);

    if (!this.requestsPerSecond)
      return this.dispatch(request, request.transformResponse);

    return this.rateLimitedRequest(() =>
      this.dispatch(request, request.transformResponse)
    );
  }

  async dispatch(request, resTransformers) {
    // Dispatch
    let response = await _network.post(request);

    // Run Response Transformers
    response = await this.factory(response, resTransformers);

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
  async factory(r, methods) {
    for (const m of methods) {
      r = await m(r);
    }
    return r;
  }
  rateLimitedRequest(request) {
    return new Promise((resolve, reject) => {
      this.buffer.push({
        request,
        resolve,
        reject,
      });

      this.processBuffer();
    });
  }

  processBuffer() {
    if (this.buffer.length === 0) {
      return;
    }

    const now = Date.now();
    const timeSinceLastRequest = now - this.lastRequestTime;

    if (timeSinceLastRequest >= 1000 / this.requestsPerSecond) {
      const { request, resolve, reject } = this.buffer.shift();

      this.lastRequestTime = now;

      request().then(resolve).catch(reject);

      // Recursively process the next request in the buffer
      this.processBuffer();
    } else {
      // Wait until enough time has passed before processing the next request
      setTimeout(
        () => this.processBuffer(),
        1000 / this.requestsPerSecond - timeSinceLastRequest
      );
    }
  }
}
