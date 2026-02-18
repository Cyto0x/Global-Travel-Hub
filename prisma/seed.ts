import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('Start seeding...')

  // Create test users
  const user1 = await prisma.user.create({
    data: {
      id: '550e8400-e29b-41d4-a716-446655440000',
      email: 'admin@globaltravelhub.com',
      fullName: 'Admin User',
      role: 'admin',
      status: 'active',
      dataProcessingConsent: true,
      consentGrantedAt: new Date(),
    },
  })

  const user2 = await prisma.user.create({
    data: {
      id: '550e8400-e29b-41d4-a716-446655440001',
      email: 'test.user@gmail.com',
      fullName: 'Test User',
      role: 'user',
      status: 'active',
      dataProcessingConsent: true,
      consentGrantedAt: new Date(),
    },
  })

  const user3 = await prisma.user.create({
    data: {
      id: '550e8400-e29b-41d4-a716-446655440002',
      email: 'john.doe@example.com',
      fullName: 'John Doe',
      role: 'user',
      status: 'active',
      dataProcessingConsent: true,
      consentGrantedAt: new Date(),
    },
  })

  console.log(`Created users: ${user1.email}, ${user2.email}, ${user3.email}`)

  // Create OAuth accounts
  await prisma.oAuthAccount.create({
    data: {
      userId: user2.id,
      provider: 'google',
      providerUserId: 'google-123456',
      providerEmail: 'test.user@gmail.com',
    },
  })

  await prisma.oAuthAccount.create({
    data: {
      userId: user3.id,
      provider: 'google',
      providerUserId: 'google-789012',
      providerEmail: 'john.doe@example.com',
    },
  })

  console.log('Created OAuth accounts')

  // Create chat sessions
  const session1 = await prisma.chatSession.create({
    data: {
      id: '660e8400-e29b-41d4-a716-446655440000',
      userId: user2.id,
      title: 'Trip to Paris',
      status: 'active',
      threadId: '770e8400-e29b-41d4-a716-446655440000',
      context: { destination: 'Paris', intent: 'flight_search' },
      messageCount: 5,
    },
  })

  const session2 = await prisma.chatSession.create({
    data: {
      id: '660e8400-e29b-41d4-a716-446655440001',
      userId: user2.id,
      title: 'Hotel in Tokyo',
      status: 'active',
      threadId: '770e8400-e29b-41d4-a716-446655440001',
      context: { destination: 'Tokyo', intent: 'hotel_search' },
      messageCount: 3,
    },
  })

  console.log(`Created chat sessions: ${session1.title}, ${session2.title}`)

  // Create chat messages
  await prisma.chatMessage.createMany({
    data: [
      {
        id: '880e8400-e29b-41d4-a716-446655440000',
        sessionId: session1.id,
        role: 'user',
        content: 'I want to book a flight from NYC to Paris in June',
      },
      {
        id: '880e8400-e29b-41d4-a716-446655440001',
        sessionId: session1.id,
        role: 'ai',
        content: "I'd be happy to help you find flights from NYC to Paris in June!",
        model: 'gpt-4',
        tokensTotal: 45,
        latencyMs: 850,
      },
    ],
  })

  console.log('Created chat messages')

  // Create cache entries
  await prisma.flightSearchCache.create({
    data: {
      id: 'f1e2d3c4-b5a6-7890-abcd-ef1234567890',
      searchHash: 'a1b2c3d4e5f6789012345678901234567890abcd1234567890abcdef12345678',
      origin: 'JFK',
      destination: 'CDG',
      departureDate: new Date('2024-06-15'),
      returnDate: new Date('2024-06-22'),
      passengersAdults: 1,
      cabinClass: 'economy',
      results: [
        { airline: 'Air France', flightNumber: 'AF006', price: 850 },
        { airline: 'Delta', flightNumber: 'DL264', price: 920 },
      ],
      resultCount: 2,
      expiresAt: new Date(Date.now() + 30 * 60 * 1000), // 30 min
      hitCount: 15,
    },
  })

  await prisma.hotelSearchCache.create({
    data: {
      id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567891',
      searchHash: 'b2c3d4e5f6a789012345678901234567890abcde1234567890abcdef123456789',
      location: 'Tokyo',
      checkIn: new Date('2024-07-01'),
      checkOut: new Date('2024-07-05'),
      guests: 2,
      rooms: 1,
      results: [
        { hotelId: 'HT123', hotelName: 'Park Hyatt Tokyo', pricePerNight: 450 },
        { hotelId: 'HT456', hotelName: 'Shibuya Excel Hotel', pricePerNight: 180 },
      ],
      resultCount: 2,
      expiresAt: new Date(Date.now() + 30 * 60 * 1000),
      hitCount: 8,
    },
  })

  console.log('Created cache entries')

  // Create bookings
  const booking1 = await prisma.booking.create({
    data: {
      id: '990e8400-e29b-41d4-a716-446655440000',
      userId: user3.id,
      bookingReference: 'GTH-ABC123',
      status: 'confirmed',
      paymentStatus: 'completed',
      totalAmount: 1250.00,
      currency: 'USD',
      contactEmail: 'john.doe@example.com',
      contactPhone: '+1-555-0123',
      chatSessionId: session2.id,
      confirmedAt: new Date(),
    },
  })

  const booking2 = await prisma.booking.create({
    data: {
      id: '990e8400-e29b-41d4-a716-446655440001',
      userId: user2.id,
      bookingReference: 'GTH-DEF456',
      status: 'confirmed',
      paymentStatus: 'completed',
      totalAmount: 2100.00,
      currency: 'USD',
      contactEmail: 'test.user@gmail.com',
      contactPhone: '+1-555-0456',
      chatSessionId: session1.id,
      confirmedAt: new Date(),
    },
  })

  console.log(`Created bookings: ${booking1.bookingReference}, ${booking2.bookingReference}`)

  // Create flight booking
  const flightBooking = await prisma.flightBooking.create({
    data: {
      id: 'aa0e8400-e29b-41d4-a716-446655440000',
      bookingReference: 'ABC123',
      airlineCode: 'BA',
      airlineName: 'British Airways',
      flightNumber: 'BA112',
      origin: 'JFK',
      destination: 'LHR',
      departureTime: new Date('2024-03-15T22:30:00Z'),
      arrivalTime: new Date('2024-03-16T08:45:00Z'),
      cabinClass: 'business',
      passengers: [{ name: 'John Doe', type: 'adult', price: 1200 }],
      passengerCount: 1,
      externalBookingId: 'EXT-12345',
    },
  })

  // Create hotel booking
  const hotelBooking = await prisma.hotelBooking.create({
    data: {
      id: 'bb0e8400-e29b-41d4-a716-446655440000',
      bookingReference: 'DEF456',
      hotelId: 'HT789',
      hotelName: 'The Peninsula Paris',
      hotelAddress: '19 Avenue Kléber, 75116 Paris, France',
      hotelRating: 5.0,
      roomType: 'Deluxe Room',
      checkIn: new Date('2024-06-15'),
      checkOut: new Date('2024-06-22'),
      nights: 7,
      guests: 2,
      rooms: 1,
      breakfastIncluded: true,
      guestsDetails: [{ name: 'Test User', type: 'adult' }],
      externalBookingId: 'EXT-67890',
    },
  })

  console.log('Created flight and hotel bookings')

  // Create booking items
  await prisma.bookingItem.create({
    data: {
      bookingId: booking1.id,
      itemType: 'flight',
      itemSequence: 1,
      flightBookingId: flightBooking.id,
      itemPrice: 1200.00,
    },
  })

  await prisma.bookingItem.create({
    data: {
      bookingId: booking2.id,
      itemType: 'hotel',
      itemSequence: 1,
      hotelBookingId: hotelBooking.id,
      itemPrice: 2100.00,
    },
  })

  console.log('Created booking items')

  // Create analytics events
  await prisma.analyticsEvent.createMany({
    data: [
      {
        eventType: 'page_view',
        userId: user2.id,
        sessionId: 'sess-123',
        eventData: { page: '/flights/search', referrer: 'google' },
      },
      {
        eventType: 'search_flight',
        userId: user2.id,
        sessionId: 'sess-123',
        eventData: { origin: 'JFK', destination: 'CDG', resultsCount: 2 },
      },
      {
        eventType: 'booking_completed',
        userId: user2.id,
        sessionId: 'sess-123',
        eventData: { bookingId: booking2.id, amount: 2100 },
      },
    ],
  })

  console.log('Created analytics events')

  console.log('Seeding finished.')
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
