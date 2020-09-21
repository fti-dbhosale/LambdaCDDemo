from enum import Enum

DATETIME_FORMAT = '%Y-%m-%d %H:%M:%S'
TIMEZONE = 'Asia/Kolkata'
CLOUD_FRONT_BASE_PROTOCOL = 'https://'

class ResponseCodes(Enum):
    SUCCESS = {"code": "10000", "message": "Success"}
    FAIL = {"code": "10100", "message": "Fail"}
    EMPTY_PAYLOAD = {"code": "10102", "message": "Empty payload"}
    EVENT_NOT_FOUND = {"code": "10400", "message": "Event not found"}
