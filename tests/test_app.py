from app import app


def test_index():
    response = app.test_client().get("/")
    assert response.status_code == 200
    assert response.json == {"service": "sec-project", "status": "ok"}


def test_healthz():
    response = app.test_client().get("/healthz")
    assert response.status_code == 200
    assert response.json["status"] == "healthy"
