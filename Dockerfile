# Use the official AFFiNE self-hosted image
FROM ghcr.io/toeverything/affine:stable

# Railway provides PORT environment variable
ENV AFFINE_SERVER_PORT=3010
ENV AFFINE_SERVER_HOST=0.0.0.0
ENV NODE_ENV=production

# Create storage directory
RUN mkdir -p /root/.affine/storage /root/.affine/config

# Copy startup script
COPY railway-start.sh /app/railway-start.sh
RUN chmod +x /app/railway-start.sh

# Expose the port (Railway will map this)
EXPOSE 3010

# Use custom startup script that handles migrations
CMD ["/app/railway-start.sh"]
