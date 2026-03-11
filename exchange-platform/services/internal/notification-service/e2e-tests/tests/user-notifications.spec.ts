import { test, expect } from '@playwright/test';

const API_BASE_URL = 'http://localhost:8080/users';

test.describe.serial('User Notifications API', () => {

  const userId = 'user-test-123';
  let notificationId: string;

  test('should create a user notification', async ({ request }) => {
    const payload = {
      message: 'System alert: please update your password',
      metadata: { priority: 'high', type: 'security' },
      activeStartDate: new Date().toISOString(),
      activeEndDate: new Date(Date.now() + 86400000).toISOString()
    };

    const response = await request.post(`${API_BASE_URL}/${userId}/notifications`, {
      data: payload
    });

    expect(response.status()).toBe(201);

    const responseBody = await response.json();
    expect(responseBody.userId).toBe(userId);
    expect(responseBody.message).toBe(payload.message);
    expect(responseBody.notificationId).toBeDefined();

    notificationId = responseBody.notificationId;
  });

  test('should get user notifications', async ({ request }) => {
    const response = await request.get(`${API_BASE_URL}/${userId}/notifications`);

    expect(response.status()).toBe(200);

    const responseBody = await response.json();
    expect(Array.isArray(responseBody)).toBeTruthy();
    expect(responseBody.length).toBeGreaterThan(0);

    // Check if the notification we created earlier is in the list
    const found = responseBody.find((n: any) => n.notificationId === notificationId);
    expect(found).toBeDefined();
    expect(found.message).toBe('System alert: please update your password');
  });

  test('should delete a user notification', async ({ request }) => {
    // Delete the notification created in the first test
    const deleteResponse = await request.delete(`${API_BASE_URL}/${userId}/notifications/${notificationId}`);
    expect(deleteResponse.status()).toBe(204);

    // Verify it's gone
    const getResponse = await request.get(`${API_BASE_URL}/${userId}/notifications`);
    const getBody = await getResponse.json();
    const found = getBody.find((n: any) => n.notificationId === notificationId);
    expect(found).toBeUndefined();
  });

});
