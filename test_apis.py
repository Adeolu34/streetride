"""
Streetride API Test Script
Rider:  09154180817
Driver: 09024706049
"""
import requests, json, sys, time, urllib3, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE        = "https://streetrideplus.com/sr"
AUTH_EP     = "http://streetrideplus.com/sr/AuthSP"
HANDLER_EP  = f"{BASE}/myhandler"
AUTH_USER   = "Paysp1010$i.i"
AUTH_KEY    = r"$2a$10$3JK3bVeSVXW0xrVzqmvUmu/tX.XLoUqbwPxTYqZdDz1QHMB2jhDxm"

RIDER_PHONE  = "09154180805"
DRIVER_PHONE = "09024706049"
PASSWORD     = "Test@1234"

# Lagos coords (Ikeja area)
RIDER_LAT, RIDER_LNG   = "6.6018", "3.3515"
DRIVER_LAT, DRIVER_LNG = "6.6050", "3.3580"
DROPOFF_LAT, DROPOFF_LNG = "6.5833", "3.3792"

TOKEN = None
RIDER_TOKEN  = None
DRIVER_TOKEN = None
REQ_ID = None

def separator(label):
    print(f"\n{'━'*60}")
    print(f"  {label}")
    print('━'*60)

def show(label, data):
    status = "✓" if not data.get("error") and data.get("status","").lower() not in ("error","failed","0","false") else "✗"
    print(f"\n[{status}] {label}")
    print(json.dumps(data, indent=2, ensure_ascii=False))
    return data

def get_token():
    global TOKEN
    r = requests.post(AUTH_EP, json={"userId": AUTH_USER, "secretKey": AUTH_KEY}, timeout=15, verify=False)
    data = r.json()
    TOKEN = data.get("token") or data.get("Token") or data.get("access_token")
    if not TOKEN:
        print("FATAL: Could not get bearer token")
        print(data)
        sys.exit(1)
    print(f"\n✓ Bearer token: {TOKEN[:40]}...")
    return TOKEN

def api(body):
    headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
    r = requests.post(HANDLER_EP, json=body, headers=headers, timeout=20, verify=False)
    try:
        return r.json()
    except Exception:
        return {"raw": r.text, "status_code": r.status_code}

# ─── PHASE 1: AUTH ────────────────────────────────────────────────────────────

def phase1_register():
    separator("PHASE 1: REGISTER BOTH ACCOUNTS")

    res = show("R10 — Register Rider", api({
        "theKey": "R10",
        "firstname": "Test",
        "surname": "Rider",
        "phone": RIDER_PHONE,
        "password": PASSWORD,
    }))

    res = show("R10.1 — Register Driver", api({
        "theKey": "R10.1",
        "firstname": "Test",
        "surname": "Driver",
        "phone": DRIVER_PHONE,
        "password": PASSWORD,
        "vtype": "Car",
        "vmake": "Toyota",
        "vmodel": "Camry",
        "vyear": "2020",
        "vcolor": "Silver",
    }))

    print("\n📱 OTP should arrive on both phones now.")
    print(f"   Rider  ({RIDER_PHONE}): check SMS")
    print(f"   Driver ({DRIVER_PHONE}): check SMS")

def phase1_verify(rider_otp, driver_otp):
    separator("PHASE 1b: VERIFY OTPs")

    show("R11 — Verify Rider OTP", api({
        "theKey": "R11",
        "phone": RIDER_PHONE,
        "otp": rider_otp,
    }))

    show("R11 — Verify Driver OTP", api({
        "theKey": "R11",
        "phone": DRIVER_PHONE,
        "otp": driver_otp,
    }))

def phase1_signin():
    global RIDER_TOKEN, DRIVER_TOKEN
    separator("PHASE 1c: SIGN IN")

    r = show("R11.1 — Sign In Rider", api({
        "theKey": "R11.1",
        "phone": RIDER_PHONE,
        "password": PASSWORD,
        "latitude": RIDER_LAT,
        "longitude": RIDER_LNG,
    }))
    RIDER_TOKEN = r.get("token") or r.get("Token") or r.get("jwt")

    d = show("R11.1 — Sign In Driver", api({
        "theKey": "R11.1",
        "phone": DRIVER_PHONE,
        "password": PASSWORD,
        "latitude": DRIVER_LAT,
        "longitude": DRIVER_LNG,
    }))
    DRIVER_TOKEN = d.get("token") or d.get("Token") or d.get("jwt")
    print(f"\n  Rider token:  {str(RIDER_TOKEN)[:30] if RIDER_TOKEN else 'None'}")
    print(f"  Driver token: {str(DRIVER_TOKEN)[:30] if DRIVER_TOKEN else 'None'}")

# ─── PHASE 2: DRIVER SETUP ────────────────────────────────────────────────────

def phase2_driver_setup():
    separator("PHASE 2: DRIVER SETUP")

    show("DS1 — Driver goes ONLINE", api({
        "theKey": "DS1",
        "phone": f"234{DRIVER_PHONE[1:]}",
        "status": "online",
    }))

    show("R11.2 — Driver updates location", api({
        "theKey": "R11.2",
        "phone": f"234{DRIVER_PHONE[1:]}",
        "latitude": DRIVER_LAT,
        "longitude": DRIVER_LNG,
        "isdriver": "1",
    }))

    show("R11.3 — Rider gets nearby drivers", api({
        "theKey": "R11.3",
        "FromLat": RIDER_LAT,
        "FromLong": RIDER_LNG,
    }))

# ─── PHASE 3: BOOKING FLOW ────────────────────────────────────────────────────

def phase3_booking():
    global REQ_ID
    separator("PHASE 3: BOOKING FLOW")

    # Rider books a ride targeting the driver
    res = show("BK1 — Rider books ride", api({
        "theKey": "BK1",
        "rphone": f"234{RIDER_PHONE[1:]}",
        "dphone": f"234{DRIVER_PHONE[1:]}",
        "fromLat": RIDER_LAT,
        "fromLong": RIDER_LNG,
        "toLat": DROPOFF_LAT,
        "toLong": DROPOFF_LNG,
        "fromText": "Ikeja, Lagos",
        "toText": "Onikan, Lagos",
        "km": "5.2",
        "tm": "18",
        "OtherText": "",
    }))
    REQ_ID = (res.get("reqid") or res.get("ReqId") or res.get("reqId")
              or res.get("id") or res.get("ID") or "")
    print(f"\n  ▶ REQ_ID = {REQ_ID}")

    time.sleep(1)

    # Driver polls for open ride requests
    show("BK2.2 — Driver polls open rides", api({
        "theKey": "BK2.2",
        "driverphone": f"234{DRIVER_PHONE[1:]}",
    }))

    if not REQ_ID:
        print("\n⚠ No reqId returned from BK1 — trying BK2.2 to get it")

    # Driver sets a price
    show("BK2 — Driver sets price (₦1500)", api({
        "theKey": "BK2",
        "reqid": REQ_ID,
        "price": "1500",
    }))

    time.sleep(1)

    # Rider polls messages
    res2 = show("BK8 — Rider polls messages", api({
        "theKey": "BK8",
        "phone": f"234{RIDER_PHONE[1:]}",
    }))

    # Rider accepts price
    show("BK3 — Rider accepts price", api({
        "theKey": "BK3",
        "reqid": REQ_ID,
        "status": "accept",
    }))

    time.sleep(1)

    # Rider polls again after acceptance
    show("BK8 — Rider polls (post-accept)", api({
        "theKey": "BK8",
        "phone": f"234{RIDER_PHONE[1:]}",
    }))

# ─── PHASE 4: NAVIGATION & TRACKING ──────────────────────────────────────────

def phase4_navigation():
    separator("PHASE 4: NAVIGATION & TRACKING")

    show("BK4 — Driver: En Route", api({
        "theKey": "BK4",
        "reqid": REQ_ID,
        "status": "En Route",
    }))

    show("R11.2 — Driver updates location (en route)", api({
        "theKey": "R11.2",
        "phone": f"234{DRIVER_PHONE[1:]}",
        "latitude": "6.6040",
        "longitude": "3.3550",
        "isdriver": "1",
    }))

    show("R11.2B — Rider gets driver location", api({
        "theKey": "R11.2B",
        "phone": f"234{DRIVER_PHONE[1:]}",
    }))

    show("BK4 — Driver: Arrived", api({
        "theKey": "BK4",
        "reqid": REQ_ID,
        "status": "Arrived",
    }))

    show("BK4 — Driver: In Transit", api({
        "theKey": "BK4",
        "reqid": REQ_ID,
        "status": "In Transit",
    }))

    show("R11.2 — Rider updates own location", api({
        "theKey": "R11.2",
        "phone": f"234{RIDER_PHONE[1:]}",
        "latitude": DROPOFF_LAT,
        "longitude": DROPOFF_LNG,
        "isdriver": "0",
    }))

# ─── PHASE 5: CHAT ────────────────────────────────────────────────────────────

def phase5_chat():
    separator("PHASE 5: CHAT (M1 / M2)")

    show("M1 — Rider sends message", api({
        "theKey": "M1",
        "ReqId": REQ_ID,
        "Phone": f"234{RIDER_PHONE[1:]}",
        "Message": "I'm at the gate, please come in",
    }))

    show("M2 — Driver reads messages", api({
        "theKey": "M2",
        "ReqId": REQ_ID,
        "Phone": f"234{DRIVER_PHONE[1:]}",
    }))

    show("M1 — Driver replies", api({
        "theKey": "M1",
        "ReqId": REQ_ID,
        "Phone": f"234{DRIVER_PHONE[1:]}",
        "Message": "Almost there, 2 minutes",
    }))

    show("M2 — Rider reads messages", api({
        "theKey": "M2",
        "ReqId": REQ_ID,
        "Phone": f"234{RIDER_PHONE[1:]}",
    }))

# ─── PHASE 6: TRIP COMPLETE ───────────────────────────────────────────────────

def phase6_complete():
    separator("PHASE 6: TRIP COMPLETE + RATING")

    show("BK6 — Rider rates driver (5 stars)", api({
        "theKey": "BK6",
        "reqid": REQ_ID,
        "rate": "5",
        "comment": "Great ride, smooth and safe",
    }))

    show("BK5 — Rider: Trip Completed", api({
        "theKey": "BK5",
        "reqid": REQ_ID,
        "status": "Trip Completed",
    }))

    show("DS1 — Driver goes OFFLINE", api({
        "theKey": "DS1",
        "phone": f"234{DRIVER_PHONE[1:]}",
        "status": "offline",
    }))

# ─── PHASE 7: WALLET & HISTORY ────────────────────────────────────────────────

def phase7_wallet():
    separator("PHASE 7: WALLET & HISTORY")

    show("BK11 — Rider wallet balance", api({
        "theKey": "BK11",
        "phone": f"234{RIDER_PHONE[1:]}",
    }))

    show("BK11 — Driver wallet balance", api({
        "theKey": "BK11",
        "phone": f"234{DRIVER_PHONE[1:]}",
    }))

    show("R11.6 — Rider payment history", api({
        "theKey": "R11.6",
        "phone": f"234{RIDER_PHONE[1:]}",
    }))

    show("R11.6 — Driver payment history", api({
        "theKey": "R11.6",
        "phone": f"234{DRIVER_PHONE[1:]}",
    }))

    show("BK12 — Driver charge history", api({
        "theKey": "BK12",
        "phone": f"234{DRIVER_PHONE[1:]}",
    }))

    if REQ_ID:
        show("M7 — Ride profile", api({
            "theKey": "M7",
            "ReqID": REQ_ID,
        }))

        show("BK7 — Flag ride (test: Green)", api({
            "theKey": "BK7",
            "reqid": REQ_ID,
            "flag": "Green",
            "comment": "All good",
        }))


# ─── ENTRYPOINT ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    phase = sys.argv[1] if len(sys.argv) > 1 else "all"

    get_token()

    if phase in ("register", "all"):
        phase1_register()

    elif phase == "verify":
        rider_otp  = sys.argv[2] if len(sys.argv) > 2 else input("Enter Rider OTP:  ")
        driver_otp = sys.argv[3] if len(sys.argv) > 3 else input("Enter Driver OTP: ")
        phase1_verify(rider_otp, driver_otp)
        phase1_signin()

    elif phase == "signin":
        phase1_signin()

    elif phase == "full":
        rider_otp  = sys.argv[2] if len(sys.argv) > 2 else input("Enter Rider OTP:  ")
        driver_otp = sys.argv[3] if len(sys.argv) > 3 else input("Enter Driver OTP: ")
        phase1_verify(rider_otp, driver_otp)
        phase1_signin()
        phase2_driver_setup()
        phase3_booking()
        phase4_navigation()
        phase5_chat()
        phase6_complete()
        phase7_wallet()

    elif phase == "ride":
        phase2_driver_setup()
        phase3_booking()
        phase4_navigation()
        phase5_chat()
        phase6_complete()
        phase7_wallet()
