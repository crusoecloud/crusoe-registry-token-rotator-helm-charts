import os
import base64
import json
import datetime
import requests
import hmac
import hashlib
import logging
from kubernetes import client, config
from kubernetes.config.config_exception import ConfigException
import sys

def get_env_var(name, required=True, default=None, mask=False):
    value = os.getenv(name, default)
    if required and not value:
        logging.error(f"Missing required environment variable: {name}")
        sys.exit(1)
    if mask:
        logging.debug(f"Loaded env: {name}=***masked***")
    else:
        logging.debug(f"Loaded env: {name}={value}")
    return value

def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s %(message)s',
        handlers=[logging.StreamHandler(sys.stdout)]
    )

def load_kube_config():
    try:
        config.load_incluster_config()
        logging.info("Loaded in-cluster Kubernetes config.")
    except ConfigException as e:
        logging.error(f"Failed to load in-cluster Kubernetes config: {e}")
        sys.exit(1)

def get_crusoe_token(api_access_key, api_secret_key, alias, expires_at_str, base_endpoint):
    request_path = "/ccr/tokens"
    request_verb = "POST"
    query_params = ""
    signature_version = "1.0"
    api_version = "/v1alpha5"
    dt = str(datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)).replace(" ", "T")
    sig_payload = api_version + request_path + "\n" + query_params + "\n" + request_verb + f"\n{dt}\n"
    decoded = base64.urlsafe_b64decode(api_secret_key + '=' * (-len(api_secret_key) % 4))
    signature = base64.urlsafe_b64encode(hmac.new(decoded, msg=bytes(sig_payload, 'ascii'), digestmod=hashlib.sha256).digest()).decode('ascii').rstrip("=")
    full_url = f"{base_endpoint}{api_version}{request_path}"
    headers = {
        'X-Crusoe-Timestamp': dt,
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {signature_version}:{api_access_key}:{signature}'
    }
    payload = {"expires_at": expires_at_str}
    if alias:
        payload["alias"] = alias
    try:
        logging.info(f"Requesting new token from {full_url}...")
        response = requests.post(full_url, headers=headers, json=payload, timeout=10)
        response.raise_for_status()
        new_token = response.json().get("token")
        if not new_token:
            logging.error("API response did not contain a 'token' field.")
            sys.exit(1)
        logging.info("Successfully generated new PAT token via API.")
        return new_token
    except requests.RequestException as e:
        logging.error(f"Error calling Crusoe API: {e}")
        if hasattr(e, 'response') and e.response is not None:
            logging.error(f"API Response Status: {e.response.status_code}")
            logging.error(f"API Response Body: {e.response.text}")
        sys.exit(1)

def update_k8s_secret(namespace, secret_name, registry_url, username, new_token):
    api = client.CoreV1Api()
    auth_string = f"{username}:{new_token}".encode('utf-8')
    encoded_auth = base64.b64encode(auth_string).decode('utf-8')
    docker_config = {
        "auths": {
            registry_url: {
                "username": username,
                "password": new_token,
                "auth": encoded_auth
            }
        }
    }
    secret_data = {
        ".dockerconfigjson": base64.b64encode(json.dumps(docker_config).encode('utf-8')).decode('utf-8')
    }
    secret_body = client.V1Secret(
        api_version="v1",
        kind="Secret",
        metadata=client.V1ObjectMeta(name=secret_name),
        data=secret_data,
        type="kubernetes.io/dockerconfigjson"
    )
    try:
        api.read_namespaced_secret(name=secret_name, namespace=namespace)
        logging.info(f"Secret '{secret_name}' exists. Updating...")
        api.replace_namespaced_secret(name=secret_name, namespace=namespace, body=secret_body)
        logging.info(f"Secret updated successfully in namespace '{namespace}'.")
    except client.ApiException as e:
        if e.status == 404:
            logging.info(f"Secret '{secret_name}' not found. Creating...")
            api.create_namespaced_secret(namespace=namespace, body=secret_body)
            logging.info("Secret created successfully in namespace '{namespace}'.")
        else:
            logging.error(f"Kubernetes API Error: {e}")
            sys.exit(1)

def main():
    setup_logging()
    namespaces_raw = get_env_var("TARGET_NAMESPACE")
    namespaces = [ns.strip() for ns in namespaces_raw.split(",") if ns.strip()]
    if not namespaces:
        logging.error("No namespaces specified in TARGET_NAMESPACE. Exiting.")
        sys.exit(1)
    secret_name = get_env_var("TARGET_SECRET_NAME", default="crusoe-image-pull-secrets")
    registry_url = get_env_var("REGISTRY_URL")
    token_lifetime_hours = int(get_env_var("TOKEN_EXPIRATION_HOURS", default="12"))
    alias = os.getenv("TOKEN_ALIAS")
    api_access_key = get_env_var("CRUSOE_ACCESS_KEY", mask=True)
    api_secret_key = get_env_var("CRUSOE_SECRET_KEY", mask=True)
    username = get_env_var("REGISTRY_USERNAME")
    base_endpoint = get_env_var("CRUSOE_BASE_ENDPOINT", default="https://api.crusoecloud.com")
    logging.info(f"Starting token rotation for secret '{secret_name}' in namespaces: {namespaces}.")
    expires_at_dt = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=token_lifetime_hours)
    expires_at_str = expires_at_dt.strftime('%Y-%m-%dT%H:%M:%SZ')
    logging.info(f"New token will expire at: {expires_at_str}")
    new_token = get_crusoe_token(api_access_key, api_secret_key, alias, expires_at_str, base_endpoint)
    load_kube_config()
    for namespace in namespaces:
        update_k8s_secret(namespace, secret_name, registry_url, username, new_token)
    logging.info("Token rotation complete.")

if __name__ == "__main__":
    main()