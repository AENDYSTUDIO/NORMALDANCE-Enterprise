// Quick API test script
const testEndpoints = async () => {
  const baseUrl = 'http://localhost:3000/api'
  
  // Test health endpoint
  try {
    const health = await fetch(`${baseUrl}/health`)
    console.log('Health:', await health.json())
  } catch (e) {
    console.log('Health endpoint not ready')
  }
  
  // Test rate limiting
  console.log('Testing rate limits...')
  for (let i = 0; i < 25; i++) {
    try {
      const res = await fetch(`${baseUrl}/health`)
      console.log(`Request ${i + 1}: ${res.status}`)
    } catch (e) {
      console.log(`Request ${i + 1}: Error`)
    }
  }
}

testEndpoints()