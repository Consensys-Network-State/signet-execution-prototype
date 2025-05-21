import { agent, privKeyStore } from './veramo/setup.js'

async function main() {
  const identifiers = await agent.didManagerFind()

  console.log(`There are ${identifiers.length} identifiers`)

  if (identifiers.length > 0) {
    for (const id of identifiers) {
      console.log(id)
      
      // Get and display private keys for this identifier
      try {
        for (const key of id.keys) {
          const privateKey = await privKeyStore.getKey({ alias: key.kid })
          console.log('Private Key:', privateKey)
        }
      } catch (error) {
        console.log('Could not get private key:', error.message)
      }
      
      console.log('..................')
    }
  }
}

main().catch(console.log)