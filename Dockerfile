# Multi-stage build for furl
FROM dart:stable AS builder

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN dart pub get

# Copy source code
COPY . .

# Build the executables
RUN dart compile exe bin/furl.dart -o furl
RUN dart compile exe bin/furl_server.dart -o furl-server

# Final runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -s /bin/bash furl

# Set working directory
WORKDIR /app

# Copy executables from builder
COPY --from=builder /app/furl /app/furl-server ./
COPY --from=builder /app/web ./web/
COPY --from=builder /app/wasm-crypto ./wasm-crypto/

# Make executables accessible and set permissions
RUN chmod +x furl furl-server && \
    chown -R furl:furl /app

# Switch to app user
USER furl

# Create volume for file sharing
VOLUME ["/shared"]

# Expose port for web server
EXPOSE 8080

# Set default command
CMD ["./furl-server"]

# Labels
LABEL org.opencontainers.image.title="Furl"
LABEL org.opencontainers.image.description="Secure file sharing with multi-layer encryption and client-side decryption"
LABEL org.opencontainers.image.source="https://github.com/cconstab/furl"
LABEL org.opencontainers.image.licenses="MIT"
