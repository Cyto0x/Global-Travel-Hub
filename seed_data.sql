-- ============================================================================
-- SEED DATA FOR DEVELOPMENT
-- Run after schema.sql to populate test data
-- ============================================================================

-- Test users
INSERT INTO users (id, email, full_name, role, status, data_processing_consent, consent_granted_at, created_at) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'admin@globaltravelhub.com', 'Admin User', 'admin', 'active', true, NOW(), NOW()),
('550e8400-e29b-41d4-a716-446655440001', 'test.user@gmail.com', 'Test User', 'user', 'active', true, NOW(), NOW()),
('550e8400-e29b-41d4-a716-446655440002', 'john.doe@example.com', 'John Doe', 'user', 'active', true, NOW(), NOW());

-- OAuth accounts
INSERT INTO oauth_accounts (user_id, provider, provider_user_id, provider_email, created_at) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'google', 'google-123456', 'test.user@gmail.com', NOW()),
('550e8400-e29b-41d4-a716-446655440002', 'google', 'google-789012', 'john.doe@example.com', NOW());

-- Chat sessions
INSERT INTO chat_sessions (id, user_id, title, status, thread_id, context, message_count, created_at, updated_at) VALUES
('660e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440001', 'Trip to Paris', 'active', '770e8400-e29b-41d4-a716-446655440000', '{"destination": "Paris", "intent": "flight_search", "dates": {"departure": "2024-06-15", "return": "2024-06-22"}}', 5, NOW() - INTERVAL '2 hours', NOW()),
('660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', 'Hotel in Tokyo', 'active', '770e8400-e29b-41d4-a716-446655440001', '{"destination": "Tokyo", "intent": "hotel_search", "dates": {"check_in": "2024-07-01", "check_out": "2024-07-05"}}', 3, NOW() - INTERVAL '1 day', NOW()),
('660e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440002', 'London Business Trip', 'archived', '770e8400-e29b-41d4-a716-446655440002', '{"destination": "London", "intent": "complete_booking"}', 12, NOW() - INTERVAL '7 days', NOW() - INTERVAL '6 days');

-- Chat messages (will be inserted into default partition)
INSERT INTO chat_messages (id, session_id, role, content, model, tokens_total, latency_ms, created_at) VALUES
('880e8400-e29b-41d4-a716-446655440000', '660e8400-e29b-41d4-a716-446655440000', 'user', 'I want to book a flight from NYC to Paris in June', NULL, NULL, NULL, NOW() - INTERVAL '2 hours'),
('880e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440000', 'ai', 'I''d be happy to help you find flights from NYC to Paris in June! Let me search for available options.', 'gpt-4', 45, 850, NOW() - INTERVAL '119 minutes'),
('880e8400-e29b-41d4-a716-446655440002', '660e8400-e29b-41d4-a716-446655440000', 'tool', '{"results": [{"flight": "AF006", "price": 850}]}', NULL, NULL, NULL, NOW() - INTERVAL '118 minutes'),
('880e8400-e29b-41d4-a716-446655440003', '660e8400-e29b-41d4-a716-446655440000', 'ai', 'I found several options! The best deal is Air France Flight AF006 for $850. Would you like me to proceed with booking?', 'gpt-4', 120, 920, NOW() - INTERVAL '117 minutes'),
('880e8400-e29b-41d4-a716-446655440004', '660e8400-e29b-41d4-a716-446655440000', 'user', 'Yes, please book it!', NULL, NULL, NULL, NOW() - INTERVAL '115 minutes');

-- Flight search cache
INSERT INTO flight_search_cache (search_hash, origin, destination, departure_date, return_date, passengers_adults, cabin_class, results, result_count, expires_at, hit_count, created_at) VALUES
('a1b2c3d4e5f6789012345678901234567890abcd1234567890abcdef12345678', 'JFK', 'CDG', '2024-06-15', '2024-06-22', 1, 'economy', 
'[{"airline": "Air France", "flight_number": "AF006", "departure": "2024-06-15T22:30:00", "arrival": "2024-06-16T12:45:00", "price": 850, "currency": "USD"}, {"airline": "Delta", "flight_number": "DL264", "departure": "2024-06-15T19:15:00", "arrival": "2024-06-16T08:30:00", "price": 920, "currency": "USD"}]'::jsonb,
2, NOW() + INTERVAL '30 minutes', 15, NOW() - INTERVAL '2 hours');

-- Hotel search cache
INSERT INTO hotel_search_cache (search_hash, location, check_in, check_out, guests, rooms, results, result_count, expires_at, hit_count, created_at) VALUES
('b2c3d4e5f6a789012345678901234567890abcde1234567890abcdef12345678', 'Tokyo', '2024-07-01', '2024-07-05', 2, 1,
'[{"hotel_id": "HT123", "hotel_name": "Park Hyatt Tokyo", "rating": 5.0, "price_per_night": 450, "total_price": 1800}, {"hotel_id": "HT456", "hotel_name": "Shibuya Excel Hotel", "rating": 4.2, "price_per_night": 180, "total_price": 720}]'::jsonb,
2, NOW() + INTERVAL '30 minutes', 8, NOW() - INTERVAL '1 day');

-- Bookings
INSERT INTO bookings (id, user_id, booking_reference, status, payment_status, total_amount, currency, contact_email, contact_phone, chat_session_id, confirmed_at, created_at) VALUES
('990e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440002', 'GTH-ABC123', 'confirmed', 'completed', 1250.00, 'USD', 'john.doe@example.com', '+1-555-0123', '660e8400-e29b-41d4-a716-446655440002', NOW() - INTERVAL '6 days', NOW() - INTERVAL '7 days'),
('990e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', 'GTH-DEF456', 'confirmed', 'completed', 2100.00, 'USD', 'test.user@gmail.com', '+1-555-0456', '660e8400-e29b-41d4-a716-446655440000', NOW() - INTERVAL '1 hour', NOW() - INTERVAL '2 hours');

-- Flight bookings
INSERT INTO flight_bookings (id, booking_reference, airline_code, airline_name, flight_number, origin, destination, departure_time, arrival_time, cabin_class, passengers, passenger_count, external_booking_id, created_at) VALUES
('aa0e8400-e29b-41d4-a716-446655440000', 'ABC123', 'BA', 'British Airways', 'BA112', 'JFK', 'LHR', '2024-03-15T22:30:00+00:00', '2024-03-16T08:45:00+00:00', 'business', '[{"name": "John Doe", "type": "adult", "price": 1200}]'::jsonb, 1, 'EXT-12345', NOW() - INTERVAL '7 days');

-- Hotel bookings
INSERT INTO hotel_bookings (id, booking_reference, hotel_id, hotel_name, hotel_address, hotel_rating, room_type, check_in, check_out, nights, guests, rooms, breakfast_included, guests_details, external_booking_id, created_at) VALUES
('bb0e8400-e29b-41d4-a716-446655440000', 'DEF456', 'HT789', 'The Peninsula Paris', '19 Avenue Kléber, 75116 Paris, France', 5.0, 'Deluxe Room', '2024-06-15', '2024-06-22', 7, 2, 1, true, '[{"name": "Test User", "type": "adult"}]'::jsonb, 'EXT-67890', NOW() - INTERVAL '2 hours');

-- Booking items
INSERT INTO booking_items (booking_id, item_type, item_sequence, flight_booking_id, hotel_booking_id, item_price, item_currency) VALUES
('990e8400-e29b-41d4-a716-446655440000', 'flight', 1, 'aa0e8400-e29b-41d4-a716-446655440000', NULL, 1200.00, 'USD'),
('990e8400-e29b-41d4-a716-446655440001', 'hotel', 1, NULL, 'bb0e8400-e29b-41d4-a716-446655440000', 2100.00, 'USD');

-- Analytics events
INSERT INTO analytics_events (event_type, user_id, session_id, event_data, created_at) VALUES
('page_view', '550e8400-e29b-41d4-a716-446655440001', 'sess-123', '{"page": "/flights/search", "referrer": "google"}'::jsonb, NOW() - INTERVAL '3 hours'),
('search_flight', '550e8400-e29b-41d4-a716-446655440001', 'sess-123', '{"origin": "JFK", "destination": "CDG", "results_count": 2}'::jsonb, NOW() - INTERVAL '2 hours'),
('chat_started', '550e8400-e29b-41d4-a716-446655440001', 'sess-123', '{"session_id": "660e8400-e29b-41d4-a716-446655440000"}'::jsonb, NOW() - INTERVAL '2 hours'),
('cache_hit', NULL, 'sess-123', '{"cache_type": "flight", "search_hash": "a1b2c3..."}'::jsonb, NOW() - INTERVAL '2 hours'),
('booking_completed', '550e8400-e29b-41d4-a716-446655440001', 'sess-123', '{"booking_id": "990e8400-e29b-41d4-a716-446655440001", "amount": 2100}'::jsonb, NOW() - INTERVAL '1 hour');

-- Update chat_sessions with correct message counts
UPDATE chat_sessions SET message_count = 5 WHERE id = '660e8400-e29b-41d4-a716-446655440000';
UPDATE chat_sessions SET message_count = 3 WHERE id = '660e8400-e29b-41d4-a716-446655440001';
UPDATE chat_sessions SET message_count = 12 WHERE id = '660e8400-e29b-41d4-a716-446655440002';
