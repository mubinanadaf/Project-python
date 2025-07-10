import urllib3
import os
import json
import logging
import uuid

from app.auth.auth_utils import pub_sub_url, publish_audit_logs

urllib3.disable_warnings()

Logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

def create_audit_payload(
    object_name,
    base_name,
    action,
    status,
    unix_start_time,
    unix_end_time,
    file_size,
    file_type,
    exception=None
):
    trx_id = str(uuid.uuid4())
    return {
        "uuid": str(uuid.uuid4()),
        "app_id": "odin_dev",
        "trx_id": trx_id,
        "component": "Data Processing",
        "object_name": base_name,
        "action": action,
        "pipeline_type": "data_ingestion",
        "status": status,
        "message": f"{object_name} processed successfully" if status.lower() == "success" else f"{object_name} failed",
        "exception": exception or "",
        "start_time": unix_start_time,
        "end_time": unix_end_time,
        "time_taken_in_sec": round((unix_end_time - unix_start_time), 2),
        "object_size_kb": {"double": round(int(file_size) / 1024, 2) if file_size else 0.0},
        "object_type": file_type
    }

def create_audits(directory, gcs_token, generated_items, unix_start_time, unix_end_time):
    """
    generated_items: list of filenames or stage names
    """
    try:
        valid_extensions = [".avro", ".ctl", ".toc"]
        valid_stages = [
            "SQL_CONNECTION",
            "DATA_EXTRACTION",
            "SCHEMA_GENERATION",
            "AVRO_CONVERSION"
        ]

        for item in generated_items:
            exception_message = ""
            status = "SUCCESS"

            if item in valid_stages:
                # Stage audit
                base_name = item
                file_size = 0
                file_type = "stage"
                action = (
                    "CONNECT TO SQL" if item == "SQL_CONNECTION"
                    else "EXTRACT DATA" if item == "DATA_EXTRACTION"
                    else "GENERATE SCHEMA" if item == "SCHEMA_GENERATION"
                    else "CONVERT TO AVRO" if item == "AVRO_CONVERSION"
                    else "PROCESS FILE"
                )
            else:
                # File audit
                file_path = os.path.join(directory, item)
                file_extension = os.path.splitext(item)[1].lower()

                if file_extension not in valid_extensions:
                    Logger.info(f"Skipping audit for unsupported file type: {item}")
                    continue

                base_name = os.path.basename(file_path)
                file_size = os.path.getsize(file_path)
                file_type = file_extension.replace(".", "")
                action = "PROCESS FILE"

            try:
                audit_payload_dict = create_audit_payload(
                    item,
                    base_name,
                    action,
                    status,
                    unix_start_time,
                    unix_end_time,
                    file_size,
                    file_type,
                    exception_message
                )

                Logger.debug(f"Publishing audit payload to Pub/Sub: {json.dumps(audit_payload_dict, indent=2)}")
                audit_payload = json.dumps(audit_payload_dict)
                publish_audit_logs(pub_sub_url, audit_payload, gcs_token)

                Logger.info(f"Audit logged for: {item}")

            except Exception as e:
                Logger.error(f"Failed to publish audit for {item}: {e}")

    except Exception as e:
        Logger.error(f"An error occurred while creating audits: {e}")
        raise
