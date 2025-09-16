# Use a lightweight base image with Python
FROM python:3.12-slim

# Create non-root user
RUN useradd -m tokenrotator

# Install Python dependencies for Kubernetes client and HTTP requests
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the script into the container
WORKDIR /app
COPY rotate_token_api.py .

# Set permissions so non-root user can read/execute
RUN chmod 644 /app/rotate_token_api.py

# Use non-root user
USER tokenrotator

# Command to run the script when the container starts
CMD ["python", "rotate_token_api.py"]