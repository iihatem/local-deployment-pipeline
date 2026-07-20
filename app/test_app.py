import app as app_module


def make_client():
    app_module.app.config.update(TESTING=True)
    return app_module.app.test_client()


def test_health_returns_ok():
    resp = make_client().get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_index_renders_build_metadata():
    resp = make_client().get("/")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "Build number" in body
    assert "Deployed by Terraform" in body


def test_api_info_exposes_expected_keys():
    payload = make_client().get("/api/info").get_json()
    for key in ("app", "build_number", "git_commit", "hostname", "started_at"):
        assert key in payload
