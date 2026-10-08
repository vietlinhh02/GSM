package api_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"gsmvoiceebackend/internal/api"
	"gsmvoiceebackend/internal/auth"
	"gsmvoiceebackend/internal/testutil"
)

func setupTestServer(t *testing.T) (*httptest.Server, *auth.SessionManager) {
	pgStore := testutil.GetTestPostgresStore(t)
	if pgStore == nil {
		t.Skip("skipping api test: postgres test store not available")
		return nil, nil
	}

	sessionManager := auth.NewSessionManager()
	server := api.NewServer(pgStore, sessionManager)

	ts := httptest.NewServer(server)
	t.Cleanup(ts.Close)

	return ts, sessionManager
}

func postJSON(t *testing.T, url string, body any) (*http.Response, string) {
	var reader io.Reader
	if raw, ok := body.(string); ok {
		reader = strings.NewReader(raw)
	} else {
		b, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal body failed: %v", err)
		}
		reader = bytes.NewReader(b)
	}

	resp, err := http.Post(url, "application/json", reader)
	if err != nil {
		t.Fatalf("POST request failed: %v", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read response body failed: %v", err)
	}
	return resp, string(respBody)
}

func getWithToken(t *testing.T, url, token string) (*http.Response, string) {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatalf("create request failed: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET request failed: %v", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read response body failed: %v", err)
	}
	return resp, string(respBody)
}

func postWithToken(t *testing.T, url, token string) (*http.Response, string) {
	req, err := http.NewRequest(http.MethodPost, url, nil)
	if err != nil {
		t.Fatalf("create request failed: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST request failed: %v", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read response body failed: %v", err)
	}
	return resp, string(respBody)
}

func TestHealth(t *testing.T) {
	ts, _ := setupTestServer(t)

	resp, body := getWithToken(t, ts.URL+"/health", "")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", resp.StatusCode)
	}
	if !strings.Contains(body, `"ok"`) {
		t.Fatalf("expected status ok in body, got: %s", body)
	}
}

func TestRegisterSuccessAndNoSecrets(t *testing.T) {
	ts, _ := setupTestServer(t)

	reqPayload := map[string]string{
		"name":     "Nguyen Van A",
		"email":    "user.a@xanhsm.vn",
		"password": "SecurePassword123!",
	}

	resp, body := postJSON(t, ts.URL+"/auth/register", reqPayload)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("expected 201 Created, got %d: %s", resp.StatusCode, body)
	}

	// Verify no secrets leaked in response
	for _, forbidden := range []string{"passwordHash", "salt", "SecurePassword123!"} {
		if strings.Contains(body, forbidden) {
			t.Fatalf("security violation: response leaked secret %q: %s", forbidden, body)
		}
	}

	var authResp api.AuthResponse
	if err := json.Unmarshal([]byte(body), &authResp); err != nil {
		t.Fatalf("failed to unmarshal register response: %v", err)
	}

	if authResp.Token == "" {
		t.Fatal("expected non-empty token")
	}
	if authResp.User.Email != "user.a@xanhsm.vn" {
		t.Fatalf("expected email user.a@xanhsm.vn, got: %s", authResp.User.Email)
	}
	if authResp.User.Name != "Nguyen Van A" {
		t.Fatalf("expected name Nguyen Van A, got: %s", authResp.User.Name)
	}
}

func TestRegisterDuplicateEmail(t *testing.T) {
	ts, _ := setupTestServer(t)

	reqPayload := map[string]string{
		"name":     "Original User",
		"email":    "same@xanhsm.vn",
		"password": "Password123",
	}
	postJSON(t, ts.URL+"/auth/register", reqPayload)

	// Attempt registration with identical email (different case)
	reqDuplicate := map[string]string{
		"name":     "Duplicate User",
		"email":    "  SAME@XanhSM.vn  ",
		"password": "AnotherPassword456",
	}
	resp, body := postJSON(t, ts.URL+"/auth/register", reqDuplicate)
	if resp.StatusCode != http.StatusConflict {
		t.Fatalf("expected 409 Conflict, got %d: %s", resp.StatusCode, body)
	}
	if !strings.Contains(body, "already registered") {
		t.Fatalf("expected duplicate error message, got: %s", body)
	}
}

func TestRegisterValidationErrors(t *testing.T) {
	ts, _ := setupTestServer(t)

	cases := []struct {
		name     string
		payload  map[string]string
		expected string
	}{
		{
			name:     "empty name",
			payload:  map[string]string{"name": "   ", "email": "v@xanh.vn", "password": "Password123"},
			expected: "name cannot be empty",
		},
		{
			name: "name too long",
			payload: map[string]string{
				"name":     strings.Repeat("a", 101),
				"email":    "v@xanh.vn",
				"password": "Password123",
			},
			expected: "name cannot exceed 100 characters",
		},
		{
			name:     "invalid email syntax",
			payload:  map[string]string{"name": "Nam", "email": "not-an-email", "password": "Password123"},
			expected: "invalid email address format",
		},
		{
			name: "display-name email",
			payload: map[string]string{
				"name":     "Nam",
				"email":    "Nam <nam@xanh.vn>",
				"password": "Password123",
			},
			expected: "invalid email address format",
		},
		{
			name:     "password too short",
			payload:  map[string]string{"name": "Nam", "email": "v@xanh.vn", "password": "short"},
			expected: "password must be at least 8 characters",
		},
		{
			name: "password too long",
			payload: map[string]string{
				"name":     "Nam",
				"email":    "v@xanh.vn",
				"password": strings.Repeat("a", 129),
			},
			expected: "password cannot exceed 128 characters",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			resp, body := postJSON(t, ts.URL+"/auth/register", tc.payload)
			if resp.StatusCode != http.StatusBadRequest {
				t.Fatalf("expected 400 Bad Request, got %d: %s", resp.StatusCode, body)
			}
			if !strings.Contains(body, tc.expected) {
				t.Fatalf("expected %q in response, got %s", tc.expected, body)
			}
		})
	}
}

func TestLoginMeAndLogout(t *testing.T) {
	ts, _ := setupTestServer(t)

	// Register
	regPayload := map[string]string{
		"name":     "Tran Thi B",
		"email":    "tranb@xanhsm.vn",
		"password": "MyStrongPassword!",
	}
	postJSON(t, ts.URL+"/auth/register", regPayload)

	// Login with correct credentials
	loginPayload := map[string]string{
		"email":    "TRANB@Xanhsm.VN",
		"password": "MyStrongPassword!",
	}
	resp, body := postJSON(t, ts.URL+"/auth/login", loginPayload)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on login, got %d: %s", resp.StatusCode, body)
	}

	var authResp api.AuthResponse
	if err := json.Unmarshal([]byte(body), &authResp); err != nil {
		t.Fatalf("unmarshal login response failed: %v", err)
	}
	token := authResp.Token

	// Call /auth/me with Bearer token
	resp, body = getWithToken(t, ts.URL+"/auth/me", token)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on /me, got %d: %s", resp.StatusCode, body)
	}

	var userResp api.UserResponse
	if err := json.Unmarshal([]byte(body), &userResp); err != nil {
		t.Fatalf("unmarshal /me response failed: %v", err)
	}
	if userResp.User.Name != "Tran Thi B" || userResp.User.Email != "tranb@xanhsm.vn" {
		t.Fatalf("unexpected user in /me: %+v", userResp.User)
	}

	// Call /auth/logout
	resp, _ = postWithToken(t, ts.URL+"/auth/logout", token)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on logout, got %d", resp.StatusCode)
	}

	// Call /auth/me again -> 401 Unauthorized
	resp, _ = getWithToken(t, ts.URL+"/auth/me", token)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized after logout, got %d", resp.StatusCode)
	}
}

func TestLoginInvalidCredentials(t *testing.T) {
	ts, _ := setupTestServer(t)

	// Register user
	regPayload := map[string]string{
		"name":     "Le Van C",
		"email":    "c@xanhsm.vn",
		"password": "SecretPassword123",
	}
	postJSON(t, ts.URL+"/auth/register", regPayload)

	// Wrong password
	resp, body := postJSON(t, ts.URL+"/auth/login", map[string]string{
		"email":    "c@xanhsm.vn",
		"password": "WrongPassword999",
	})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized on wrong password, got %d", resp.StatusCode)
	}
	if !strings.Contains(body, "Invalid email or password") {
		t.Fatalf("expected generic error message, got: %s", body)
	}

	// Unknown account
	resp, body = postJSON(t, ts.URL+"/auth/login", map[string]string{
		"email":    "nonexistent@xanhsm.vn",
		"password": "SecretPassword123",
	})
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized on unknown account, got %d", resp.StatusCode)
	}
	if !strings.Contains(body, "Invalid email or password") {
		t.Fatalf("expected generic error message, got: %s", body)
	}
}

func TestAuthMeUnauthorizedCases(t *testing.T) {
	ts, sm := setupTestServer(t)

	// Missing header
	resp, _ := getWithToken(t, ts.URL+"/auth/me", "")
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 on missing auth, got %d", resp.StatusCode)
	}

	// Invalid token
	resp, _ = getWithToken(t, ts.URL+"/auth/me", "invalid-token-here")
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 on invalid token, got %d", resp.StatusCode)
	}

	// Expired token
	expiredToken, _ := sm.CreateSessionWithTTL("test-user", -10*time.Minute)
	resp, _ = getWithToken(t, ts.URL+"/auth/me", expiredToken)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 on expired token, got %d", resp.StatusCode)
	}
}

func TestJSONRequestEdgeCases(t *testing.T) {
	ts, _ := setupTestServer(t)

	// 1. Malformed JSON
	resp, _ := postJSON(t, ts.URL+"/auth/register", `{"name": "A", "email": "a@x.vn"`)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 on malformed JSON, got %d", resp.StatusCode)
	}

	// 2. Trailing JSON
	resp, _ = postJSON(t, ts.URL+"/auth/register", `{"name":"A","email":"a@x.vn","password":"Pass1234"}{"more":1}`)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 on trailing JSON, got %d", resp.StatusCode)
	}

	// 3. Unknown field
	resp, _ = postJSON(t, ts.URL+"/auth/register", `{"name":"A","email":"a@x.vn","password":"Pass1234","admin":true}`)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 on unknown field, got %d", resp.StatusCode)
	}

	// 4. Exceeded body limit (16KB)
	largeBody := fmt.Sprintf(`{"name": "%s", "email": "a@x.vn", "password": "Password123"}`, strings.Repeat("X", 20000))
	resp, _ = postJSON(t, ts.URL+"/auth/register", largeBody)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 on large body exceeding limit, got %d", resp.StatusCode)
	}
}
