# StreetRide API Test Results
**Date:** 2026-07-28  
**Base URL:** `https://streetrideplus.com/sr/myhandler`  
**Auth URL:** `http://streetrideplus.com/sr/AuthSP`  
**Test Rider:** `2349024706049`  
**Test Driver:** `2349154180805`  
**Test ReqId (pending):** `eb20d60b-b95d-4dc0-8645-39235ada17f5`  
**Test ReqId (full flow):** `078f2792-f5e1-4b5f-b3c8-7ea16d4ff7fe`

---

## Auth — Get Bearer Token
**Endpoint:** `POST http://streetrideplus.com/sr/AuthSP`  
**Body:** `{ "userId": "Paysp1010$i.i", "secretKey": "..." }`

```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```
> Token expires in ~30 days. Cache in SharedPreferences (`sr_bearer_token`).

---

## BK1 — Book Ride (Rider → Driver)
**theKey:** `BK1`  
**Fields:** `rphone`, `dphone`, `fromLat`, `fromLong`, `toLat`, `toLong`, `fromText`, `toText`, `km`, `tm`, `OtherText`

```json
{
  "IsValid": true,
  "reqid": "078f2792-f5e1-4b5f-b3c8-7ea16d4ff7fe",
  "Message": "Ride request created"
}
```
> Returns a `reqid` UUID used in all subsequent calls for this ride.

---

## BK2 — Driver Sets Price
**theKey:** `BK2`  
**Fields:** `reqid`, `price`

```json
{
  "IsValid": true,
  "Message": "Driver replied"
}
```

---

## BK2.1 — Driver Adjusts/Reduces Price
**theKey:** `BK2.1`  
**Fields:** `reqid`, `price`

```json
{
  "IsValid": true,
  "Message": "Price reduced successfully"
}
```
> Used after rider rejects the initial price and negotiates.

---

## BK2.2 — Driver Fetches Open Rides
**theKey:** `BK2.2`  
**Fields:** `driverphone`

```json
{
  "IsValid": true,
  "DriverPhone": "2349154180805",
  "Status": "Busy",
  "OpenRides": 1,
  "RideDetails": [
    {
      "id": "23",
      "reqid": "24a94b50-7404-4901-a523-82a6a05aec7b",
      "rphone": "2349024706049",
      "dphone": "2349154180805",
      "Rname": "Test Rider",
      "Dname": "Test Driver",
      "sender": "rider",
      "fromText": "Lagos Island",
      "toText": "Ikeja",
      "fromLat": "6.5244",
      "fromLong": "3.3792",
      "toLat": "6.6018",
      "toLong": "3.3501",
      "km": "15",
      "tm": "25 mins",
      "Price_D": "",
      "ConfirmStatus_D": "accept",
      "ConfirmStatus_R": "accept",
      "RideStatus_R": "Trip Completed",
      "MovtStatus_D": "Trip Completed",
      "Reqtime": "7/28/2026 8:54:46 AM"
    }
  ],
  "Message": "Complete or Cancel the Open Rides"
}
```
> **BUG:** Response key is `RideDetails` but app was looking for `Rides`/`Messages` — fixed to use `BK8` instead.  
> **BUG:** Driver stays "Busy" even when all rides are completed/cancelled — backend query does not filter by status.

---

## BK3 — Rider Accepts or Rejects Price
**theKey:** `BK3`  
**Fields:** `reqid`, `status` (`accept` | `reject`)

```json
{
  "IsValid": true,
  "Message": "Rider decision saved"
}
```

---

## BK4 — Driver Sets Movement Status
**theKey:** `BK4`  
**Fields:** `reqid`, `status`  
**Valid statuses:** `En Route`, `Arrived`, `Trip Completed`, `Ride Cancel`, `Cancel`, `Set Price`

```json
{ "IsValid": true, "Message": "Movement updated" }
```
> Full flow tested: `En Route` → `Arrived` → `Trip Completed`. All return `Movement updated`.

---

## BK5 — Rider Sets Ride Status
**theKey:** `BK5`  
**Fields:** `reqid`, `status`  
**Valid statuses:** `Trip Completed`, `Ride Cancel`

```json
{
  "IsValid": true,
  "Message": "Ride status updated"
}
```

---

## BK6 — Rider Rates Driver
**theKey:** `BK6`  
**Fields:** `reqid`, `rate`, `comment`

```json
{
  "IsValid": false,
  "Message": "CarCondition must be a valid Value"
}
```
> **BUG FOUND:** BK6 requires additional fields not documented in the API wrapper. Need to add `carcondition`, `safety`, `fairness` fields. Update `RideApi.rateDriver()` to include these.

---

## BK7 — Flag a Ride
**theKey:** `BK7`  
**Fields:** `reqid`, `flag` (`Red` | `Yellow` | `Green`), `comment`

```json
{
  "IsValid": true,
  "Message": "Driver flag submitted"
}
```

---

## BK8 — Poll Messages (Rider or Driver)
**theKey:** `BK8`  
**Fields:** `phone`

**Rider response (2349024706049):**
```json
{
  "IsValid": true,
  "Phone": "2349024706049",
  "Count": 8,
  "Messages": [
    {
      "id": "30",
      "reqid": "eb20d60b-b95d-4dc0-8645-39235ada17f5",
      "rphone": "2349024706049",
      "dphone": "2349154180805",
      "sender": "rider",
      "fromText": "Ajah, Lagos",
      "toText": "Victoria Island, Lagos",
      "km": "18",
      "tm": "30",
      "Price_D": "",
      "ConfirmStatus_D": "",
      "ConfirmStatus_R": "",
      "MovtStatus_D": "",
      "RideStatus_R": "",
      "Reqtime": "7/28/2026 4:25:26 PM",
      "Rname": "Test Rider",
      "Dname": "Test Driver",
      "DriverQualityScore": 0.5,
      "LatestChats": [null, null]
    }
  ]
}
```
> Returns all messages where phone is either rider or driver. Use for driver-side pending requests by filtering: `dphone == driverPhone AND Price_D == "" AND MovtStatus_D == "" AND RideStatus_R == ""`.

---

## BK9 — Set Driver Availability
**theKey:** `BK9`  
**Fields:** `phone`, `status` (`Free` | `Busy`)

```json
{
  "Status": true,
  "Message": "status updated"
}
```

---

## BK11 — Get Wallet Status
**theKey:** `BK11`  
**Fields:** `phone`

```json
{
  "Status": "ExpiredWallet",
  "ToBalance": "100.00",
  "TotalBalance": "0.00"
}
```
> **Note:** Both test accounts have `ExpiredWallet` status and zero balance. Status values seen: `ExpiredWallet`. Expected active values: `Active`, `Free`.

---

## BK12 — Driver Charge/Subscription History
**theKey:** `BK12`  
**Fields:** `phone`

```json
{
  "success": true,
  "message": "Charging history retrieved successfully.",
  "history": []
}
```
> Empty for test accounts — no subscription charges yet.

---

## DS1 — Driver Online/Offline Status
**theKey:** `DS1`  
**Fields:** `phone`, `status` (`online` | `offline`)

```json
""
```
> **Note:** Returns empty string (not a JSON object). Handle in app with null/empty check.

---

## M1 — Send Chat Message
**theKey:** `M1`  
**Fields:** `ReqId`, `Phone`, `Message`

```json
{
  "Success": true,
  "Message": "Message sent successfully",
  "Data": {
    "Id": 28,
    "ReqId": "eb20d60b-b95d-4dc0-8645-39235ada17f5",
    "Phone": "2349024706049",
    "MessageText": "Test chat message"
  }
}
```

---

## M2 — Get Chat Messages
**theKey:** `M2`  
**Fields:** `ReqId`, `Phone`

```json
{
  "Success": true,
  "Count": 0,
  "Messages": []
}
```
> Messages stored per `ReqId`. Poll regularly during active ride.

---

## M3 — Get User Profile by Phone
**theKey:** `M3`  
**Fields:** `Phone`

**Rider:**
```json
{
  "Success": true,
  "Message": "Profile retrieved successfully",
  "Data": {
    "Id": 11,
    "Phone": "2349024706049",
    "FirstName": "Test",
    "Surname": "Rider",
    "Email": "",
    "City": "",
    "Image": "",
    "IsDriver": 0,
    "Status": 1,
    "Suspended": 0,
    "Kyc": 0,
    "VType": "", "VMake": "", "VModel": "", "VYear": "", "VColor": "",
    "GBody": 0, "AC": 0,
    "BankNo": ""
  }
}
```

**Driver:**
```json
{
  "Success": true,
  "Message": "Profile retrieved successfully",
  "Data": {
    "Id": 12,
    "Phone": "2349154180805",
    "FirstName": "Test",
    "Surname": "Driver",
    "Email": "",
    "City": "Lagos",
    "Image": "",
    "IsDriver": 1,
    "Status": 1,
    "Suspended": 0,
    "Kyc": 0,
    "VType": "", "VMake": "", "VModel": "", "VYear": "", "VColor": "",
    "GBody": 0, "AC": 0,
    "BankNo": ""
  }
}
```

---

## M7 — Get Ride Profile (Both Users for a Trip)
**theKey:** `M7`  
**Fields:** `ReqID`

```json
{
  "Success": true,
  "UserProfileRider": {
    "id": 11, "phone": "2349024706049",
    "firstname": "Test", "surname": "Rider",
    "isdriver": 0, "thestatus": 1, "suspended": 0, "kyc": 0
  },
  "UserProfileDriver": {
    "id": 12, "phone": "2349154180805",
    "firstname": "Test", "surname": "Driver",
    "city": "Lagos", "isdriver": 1, "thestatus": 1, "suspended": 0, "kyc": 0
  }
}
```

---

## R11.2 — Update GPS Location
**theKey:** `R11.2`  
**Fields:** `phone`, `latitude`, `longitude`, `isdriver` (`0` | `1`)

```json
{
  "IsValid": true,
  "Error": "00",
  "Message": "Location updated successfully"
}
```

---

## R11.2B — Get Last Known Location
**theKey:** `R11.2B`  
**Fields:** `phone`

**Rider:**
```json
{
  "IsValid": true,
  "Error": "00",
  "Message": "Success",
  "Data": {
    "phone": "2349024706049",
    "longitude": "0",
    "latitude": "0",
    "isDriver": "0",
    "lastUpdated": "7/28/2026 4:04:22 PM"
  }
}
```

**Driver:**
```json
{
  "IsValid": true,
  "Error": "00",
  "Message": "Success",
  "Data": {
    "phone": "2349154180805",
    "longitude": "0",
    "latitude": "0",
    "isDriver": "1",
    "lastUpdated": "7/28/2026 3:28:21 PM"
  }
}
```

---

## R11.3 — Get Nearby Drivers
**theKey:** `R11.3`  
**Fields:** `FromLat`, `FromLong`

```json
{
  "IsValid": true,
  "Count": 2,
  "Users": [
    {
      "phone": "2349033196647",
      "isDriver": true,
      "status": "",
      "latitude": 6.6593383,
      "longitude": 3.353015,
      "distance_km": 33.2,
      "minutes_away": "33",
      "lastUpdated": "7/7/2026 8:41:24 PM",
      "firstname": "", "surname": "",
      "total_rides": 0,
      "avg_rating": 0.0,
      "DriverQualityScore": 0.5
    },
    {
      "phone": "2349154180805",
      "isDriver": true,
      "status": "Free",
      "latitude": 0.0,
      "longitude": 0.0,
      "distance_km": 822.07,
      "minutes_away": "822",
      "lastUpdated": "7/28/2026 3:28:21 PM",
      "firstname": "Test", "surname": "Driver",
      "city": "Lagos",
      "total_rides": 1,
      "avg_rating": 0.0,
      "DriverQualityScore": 0.5
    }
  ]
}
```

---

## R11.6 — Payment / Trip History
**theKey:** `R11.6`  
**Fields:** `phone`

```json
{
  "IsValid": true,
  "Phone": "2349024706049",
  "TotalTransactions": 0,
  "History": []
}
```
> Both test accounts return empty history. `History` array contains ride objects with `Price_D`, `toText`, `Reqtime`, `RideStatus_R`, `MovtStatus_D` when populated.

---

## R15 — KYC Document Templates
**theKey:** `R15`  
**Fields:** `Phone`, `City`

```json
{
  "templates": []
}
```
> No KYC templates configured for Lagos yet.

---

## R16 — Pending KYC Documents for Driver
**theKey:** `R16`  
**Fields:** `Phone`, `City`

```json
{
  "PendingCount": 0,
  "PendingDocuments": []
}
```

---

## RR1 — Address Autocomplete
**theKey:** `RR1`  
**Fields:** `Address`

```json
{
  "status": true,
  "predictions": [
    {
      "PlaceId": "AQAAAFUAs9an...",
      "Description": "Victoria Island Sec School",
      "Address": "Victoria Island Sec School, Balarabe Musa Cres, Eti-Osa, Nigeria"
    },
    {
      "PlaceId": "AQAAAFUAYqTi...",
      "Description": "Victoria Island Primary School",
      "Address": "Victoria Island Primary School, Bishop Aboyade Cole St, Eti-Osa, Nigeria"
    }
  ]
}
```
> Display `Address` field to the user. Store `PlaceId` internally for RR2 resolution. **Never show PlaceId in the UI.**

---

## RR2 — Resolve PlaceId to Coordinates
**theKey:** `RR2`  
**Fields:** `PlaceId`

```json
{
  "status": true,
  "place": {
    "PlaceId": "AQAAAFUAs9an...",
    "Label": "Victoria Island Sec School, Balarabe Musa Cres, Eti-Osa, Nigeria",
    "Street": "Balarabe Musa Cres",
    "City": "Lagos",
    "State": { "Code": null, "Name": "Lagos" },
    "Country": "Nigeria",
    "PostalCode": null,
    "Latitude": 6.43744,
    "Longitude": 3.43893
  }
}
```

---

## RR3 — Reverse Geocode (Lat/Long → Address)
**theKey:** `RR3`  
**Fields:** `Latitude`, `Longitude`

```json
{
  "status": true,
  "address": {
    "Label": "Lagos-Epe Exp Rd, Eti-Osa, Nigeria",
    "Street": "Lagos-Epe Exp Rd",
    "City": "Lagos",
    "State": { "Code": null, "Name": "Lagos" },
    "Country": "Nigeria",
    "PostalCode": null,
    "Latitude": 6.4698,
    "Longitude": 3.5852
  }
}
```
> Used to label the rider's current GPS location as a human-readable address.

---

## Known Issues / Bugs Found During Testing

| # | Endpoint | Issue | Severity |
|---|----------|-------|----------|
| 1 | `BK2.2` | Returns `RideDetails` key but app was parsing `Rides`/`Messages` — driver always saw empty list | Fixed (switched to BK8) |
| 2 | `BK2.2` | Driver stays `Busy` even when all rides are `Trip Completed` or `Ride Cancel` — backend filter bug | Backend fix needed |
| 3 | `BK6` | Requires `carcondition`, `safety`, `fairness` fields but `RideApi.rateDriver()` doesn't send them — returns `IsValid: false` | App fix needed |
| 4 | `DS1` | Returns empty string `""` instead of a JSON object | Handle in app with empty-string check |
| 5 | `BK11` | Both test accounts show `ExpiredWallet` — wallet/subscription not activated | Test data issue |
| 6 | `R11.6` | Both accounts return empty `History` — no completed paid rides yet | Expected for test accounts |
| 7 | `R11.3` | Driver location is `0,0` — GPS not updating in real-time | Driver needs to enable location |

---

## Ride Flow (Happy Path)

```
BK1  →  BK2  →  BK3 (accept)  →  BK4 (En Route)  →  BK4 (Arrived)  →  BK5 (Trip Completed)  →  BK4 (Trip Completed)  →  BK6 (rate)
```

**Poll during active ride:** Use `BK8` every few seconds to detect status changes on both rider and driver side.
