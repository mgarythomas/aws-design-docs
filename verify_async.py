
import requests
import time
import json
import socket

def wait_for_port(port, timeout=60):
    start_time = time.time()
    while True:
        try:
            with socket.create_connection(("localhost", port), timeout=1):
                return True
        except (socket.timeout, ConnectionRefusedError):
            if time.time() - start_time > timeout:
                return False
            time.sleep(1)

def verify_async_submission():
    print("Waiting for server to start on port 3000...")
    if not wait_for_port(3000):
        print("Server failed to start.")
        return False

    url = "http://localhost:3000/api/submit"
    data = {
        "corporateActionGeneralInformation": {
            "officialCorporateActionEventID": "CA-TEST-001",
            "eventType": "DVCA",
            "mandatoryVoluntaryEventType": "MAND"
        },
        "corporateActionDetails": {
             "dates": {
                 "announcementDate": "2023-10-01",
                 "recordDate": "2023-10-15",
                 "paymentDate": "2023-10-20"
             },
             "rateAndPrice": {
                 "grossDividendRate": {
                     "amount": 0.50,
                     "currency": "USD"
                 }
             }
        },
        "underlyingSecurity": {
            "isin": "US0000000001",
            "ticker": "TST"
        },
        "options": [
            { "optionNumber": "001", "optionType": "CASH", "defaultOption": True }
        ]
    }

    try:
        response = requests.post(url, json=data)
        print(f"Response Status Code: {response.status_code}")
        print(f"Response Body: {response.text}")

        if response.status_code == 202:
            print("Successfully received 202 Accepted.")

            # Wait for async processing
            time.sleep(2)

            # Check logs
            with open("web-ui/server.log", "r") as f:
                logs = f.read()

            expected_logs = [
                "DMZ Service: Received submission",
                "[EventBus] Published event",
                "Internal Service: Processing event",
                "Internal Service: Successfully saved ENCRYPTED Corporate Action CA-TEST-001"
            ]

            all_found = True
            for expected in expected_logs:
                if expected in logs:
                    print(f"Log found: {expected}")
                else:
                    print(f"Log MISSING: {expected}")
                    all_found = False

            if all_found:
                print("Async flow verification PASSED.")
                return True
            else:
                print("Async flow verification FAILED (Logs missing).")
                return False
        else:
            print(f"Failed: Expected 202, got {response.status_code}")
            return False

    except Exception as e:
        print(f"Exception during request: {e}")
        return False

if __name__ == "__main__":
    verify_async_submission()
