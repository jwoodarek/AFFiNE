# =============================================================================
# AFFiNE Custom Build - For Development & Customization
# =============================================================================
# Start from official image, layer your customizations on top
# This is faster than building from scratch while still allowing changes
# =============================================================================

FROM ghcr.io/toeverything/affine:stable

# Your customizations go here
# Example: Add custom config
# COPY custom-config.json /root/.affine/config/

# Environment
ENV NODE_ENV=production
ENV AFFINE_SERVER_PORT=3010
ENV AFFINE_SERVER_HOST=0.0.0.0

# Create storage directories
RUN mkdir -p /root/.affine/storage /root/.affine/config

EXPOSE 3010

# The base image has the correct entrypoint
CMD ["sh", "-c", "node ./scripts/self-host-predeploy.js && node ./dist/index.js"]
