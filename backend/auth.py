import json
from functools import wraps
from flask import session, redirect, url_for, request

class Auth:
    def __init__(self, config_path):
        with open(config_path) as f:
            self.config = json.load(f)

    def check_credentials(self, username, password):
        return (
            username == self.config["auth"]["username"] and
            password == self.config["auth"]["password"]
        )

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get("logged_in"):
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return decorated_function
