import com.example.hongmengzhian.AiHttpTransport;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/** Executes the production Android HTTP class on a JVM against a loopback fixture.
 * This verifies transport logic, not an Android device or real vendor account. */
public class NativeHttpTest {
    interface Checked { void run() throws Exception; }
    static int passed = 0;
    static void check(boolean condition) { if (!condition) throw new AssertionError(); }
    static void rejects(Checked action) throws Exception {
        boolean failed = false;
        try { action.run(); } catch (Exception expected) { failed = true; }
        check(failed);
    }
    static void test(String name, Checked action) throws Exception {
        action.run(); passed++; System.out.println("PASS " + name);
    }
    public static void main(String[] args) throws Exception {
        ExecutorService executor = Executors.newCachedThreadPool();
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.setExecutor(executor);
        AtomicInteger targetHits = new AtomicInteger();
        CountDownLatch cancelStarted = new CountDownLatch(1);
        server.createContext("/models", exchange -> {
            check("GET".equals(exchange.getRequestMethod()));
            check("Bearer fixture-only".equals(exchange.getRequestHeaders().getFirst("Authorization")));
            byte[] bytes = "{\"data\":[{\"id\":\"deepseek-chat\"}]}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, bytes.length); exchange.getResponseBody().write(bytes); exchange.close();
        });
        server.createContext("/chat", exchange -> {
            check("POST".equals(exchange.getRequestMethod()));
            check("中文请求".equals(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8)));
            byte[] bytes = "中文回复".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, bytes.length); exchange.getResponseBody().write(bytes); exchange.close();
        });
        server.createContext("/redirect", exchange -> {
            exchange.getResponseHeaders().set("Location", "/target");
            exchange.sendResponseHeaders(302, -1); exchange.close();
        });
        server.createContext("/target", exchange -> {
            targetHits.incrementAndGet(); exchange.sendResponseHeaders(200, -1); exchange.close();
        });
        server.createContext("/error", exchange -> {
            byte[] bytes = "fixture-secret-echo".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(401, bytes.length); exchange.getResponseBody().write(bytes); exchange.close();
        });
        server.createContext("/large", exchange -> {
            try {
                byte[] bytes = new byte[2048]; exchange.sendResponseHeaders(200, bytes.length);
                exchange.getResponseBody().write(bytes);
            } finally { exchange.close(); }
        });
        server.createContext("/chunked", exchange -> {
            try {
                exchange.sendResponseHeaders(200, 0); exchange.getResponseBody().write(new byte[2048]);
            } finally { exchange.close(); }
        });
        server.createContext("/slow", exchange -> {
            try { Thread.sleep(500); exchange.sendResponseHeaders(200, -1); }
            catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
            finally { exchange.close(); }
        });
        server.createContext("/cancel", exchange -> {
            try {
                exchange.sendResponseHeaders(200, 0);
                exchange.getResponseBody().write('x'); exchange.getResponseBody().flush();
                cancelStarted.countDown();
                Thread.sleep(500);
            } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
            finally { exchange.close(); }
        });
        server.start();
        String base = "http://127.0.0.1:" + server.getAddress().getPort();
        AiHttpTransport transport = new AiHttpTransport();
        try {
            test("GET authentication and model body", () -> {
                AiHttpTransport.Result result = transport.request("get", base + "/models", "GET",
                    Collections.singletonMap("Authorization", "Bearer fixture-only"), "", 2000, 1048576);
                check(result.status == 200 && result.body.contains("deepseek-chat"));
            });
            test("POST Chinese UTF-8 body and response", () -> {
                AiHttpTransport.Result result = transport.request("post", base + "/chat", "POST",
                    Collections.emptyMap(), "中文请求", 2000, 1048576);
                check("中文回复".equals(result.body));
            });
            test("redirect rejected with zero second-hop requests", () -> {
                check(transport.request("redirect", base + "/redirect", "GET", Collections.emptyMap(), "", 2000, 1024).status == 302);
                check(targetHits.get() == 0);
            });
            test("provider error bodies are discarded", () -> {
                AiHttpTransport.Result result = transport.request("error", base + "/error", "GET", Collections.emptyMap(), "", 2000, 1024);
                check(result.status == 401 && result.body.isEmpty());
            });
            test("content-length bound", () -> rejects(() -> transport.request("large", base + "/large", "GET", Collections.emptyMap(), "", 2000, 1024)));
            test("chunked streaming bound", () -> rejects(() -> transport.request("chunked", base + "/chunked", "GET", Collections.emptyMap(), "", 2000, 1024)));
            test("read timeout", () -> rejects(() -> transport.request("timeout", base + "/slow", "GET", Collections.emptyMap(), "", 50, 1024)));
            test("cancellation before native dispatch", () -> {
                transport.cancel("pre-cancel");
                rejects(() -> transport.request("pre-cancel", base + "/target", "GET", Collections.emptyMap(), "", 2000, 1024));
                check(targetHits.get() == 0);
            });
            test("in-flight cancellation", () -> {
                Future<AiHttpTransport.Result> pending = executor.submit(() -> transport.request("cancel", base + "/cancel", "GET", Collections.emptyMap(), "", 2000, 1024));
                check(cancelStarted.await(1, TimeUnit.SECONDS)); transport.cancel("cancel");
                rejects(() -> pending.get(3, TimeUnit.SECONDS));
            });
            System.out.println("Native HTTP: " + passed + " passed, 0 failed");
        } finally { transport.shutdown(); server.stop(0); executor.shutdownNow(); }
    }
}
