# Use the official OPA image as the base
FROM openpolicyagent/opa:latest

# Copy the policy files into the container
COPY . /policies

# Start the OPA server
CMD ["run", "--server", "--addr", ":8181", "/policies"]
