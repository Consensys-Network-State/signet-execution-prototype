import { agent, privKeyStore } from './veramo/setup.js'

async function main() {
  var args = process.argv.slice(2);
  let alias = args[0]; // eg. 'partyA'
  const identifier = await agent.didManagerGetByAlias({ alias })
  const kid = identifier.keys[0].kid;

  const privKey = await privKeyStore.getKey({ alias: kid })
  console.log(JSON.stringify(privKey, null, 2))
}

main().catch(console.log)