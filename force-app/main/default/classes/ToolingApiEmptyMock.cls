public class ToolingApiEmptyMock implements HttpCalloutMock {
  private Integer callCount = 0;

  public HTTPResponse respond(HTTPRequest req) {
    // Delegate to the richer ToolingApiMock default payload so existing tests that
    // set ToolingApiEmptyMock continue to receive useful search->query responses.
    ToolingApiMock delegate = ToolingApiMock.defaultMock();
    return delegate.respond(req);
  }
}
