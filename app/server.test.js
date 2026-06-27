const request = require('supertest');
const app = require('../server');

jest.mock('pg', () => {
  const mockPool = { query: jest.fn() };
  return { Pool: jest.fn(() => mockPool) };
});

const { Pool } = require('pg');
const mockPool = new Pool();

describe('Health Check', () => {
  it('GET /health returns 200', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('Items API', () => {
  it('GET /items returns array', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [{ id: 1, name: 'Test' }] });
    const res = await request(app).get('/items');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('POST /items creates item', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [{ id: 1, name: 'New Item' }] });
    const res = await request(app)
      .post('/items')
      .send({ name: 'New Item', description: 'Test desc' });
    expect(res.statusCode).toBe(201);
    expect(res.body.name).toBe('New Item');
  });

  it('POST /items without name returns 400', async () => {
    const res = await request(app).post('/items').send({});
    expect(res.statusCode).toBe(400);
  });

  it('DELETE /items/:id returns 204', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app).delete('/items/1');
    expect(res.statusCode).toBe(204);
  });
});
