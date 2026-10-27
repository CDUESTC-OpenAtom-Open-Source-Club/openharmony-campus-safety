package com.example.hongmengzhian;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Uses platform TLS validation. Never follows redirects or shares a cookie jar. */
public final class AiHttpTransport {
    public static final class Result {
        public final int status;
        public final String body;
        Result(int status, String body) { this.status = status; this.body = body; }
    }

    private final ConcurrentHashMap<String, HttpURLConnection> requests = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Long> canceled = new ConcurrentHashMap<>();

    public Result request(String id, String endpoint, String method, Map<String, String> headers,
                          String body, int timeout, int limit) throws Exception {
        HttpURLConnection connection = null;
        long deadline = System.nanoTime() + Math.min(120000, timeout) * 1000000L;
        try {
            if (canceled.containsKey(id)) throw new IllegalStateException();
            URI uri = new URI(endpoint);
            if (uri.getUserInfo() != null || uri.getFragment() != null) throw new IllegalArgumentException();
            if (!"https".equals(uri.getScheme()) && !"http".equals(uri.getScheme())) throw new IllegalArgumentException();
            if (!"GET".equals(method) && !"POST".equals(method)) throw new IllegalArgumentException();
            if (limit <= 0 || timeout <= 0) throw new IllegalArgumentException();
            limit = Math.min(1048576, limit);
            connection = (HttpURLConnection) uri.toURL().openConnection();
            connection.setInstanceFollowRedirects(false);
            connection.setUseCaches(false);
            connection.setConnectTimeout(Math.min(15000, timeout));
            connection.setReadTimeout(Math.min(120000, timeout));
            connection.setRequestMethod(method);
            for (Map.Entry<String, String> header : headers.entrySet()) {
                String value = header.getValue();
                if (value.indexOf('\r') >= 0 || value.indexOf('\n') >= 0) throw new IllegalArgumentException();
                connection.setRequestProperty(header.getKey(), value);
            }
            requests.put(id, connection);
            if (canceled.containsKey(id)) throw new IllegalStateException();
            if ("POST".equals(method)) {
                connection.setDoOutput(true);
                byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
                connection.setFixedLengthStreamingMode(bytes.length);
                try (java.io.OutputStream output = connection.getOutputStream()) { output.write(bytes); }
            }
            int status = connection.getResponseCode();
            if (status < 200 || status >= 300) return new Result(status, "");
            if (connection.getContentLengthLong() > limit) throw new IllegalArgumentException();
            try (InputStream input = connection.getInputStream(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[8192]; int count;
                while ((count = input.read(buffer)) != -1) {
                    if (canceled.containsKey(id) || System.nanoTime() > deadline || output.size() + count > limit) {
                        throw new IllegalStateException();
                    }
                    output.write(buffer, 0, count);
                    int remaining = (int) Math.max(1, (deadline - System.nanoTime()) / 1000000L);
                    connection.setReadTimeout(remaining);
                }
                if (canceled.containsKey(id)) throw new IllegalStateException();
                return new Result(status, new String(output.toByteArray(), StandardCharsets.UTF_8));
            }
        } finally {
            if (connection != null) connection.disconnect();
            requests.remove(id); canceled.remove(id);
        }
    }

    public void cancel(String id) {
        long now = System.nanoTime();
        canceled.entrySet().removeIf(entry -> now - entry.getValue() > 130000000000L);
        canceled.put(id, now);
        HttpURLConnection connection = requests.get(id);
        if (connection != null) connection.disconnect();
    }

    public void shutdown() {
        for (Map.Entry<String, HttpURLConnection> entry : requests.entrySet()) cancel(entry.getKey());
        requests.clear();
    }
}
