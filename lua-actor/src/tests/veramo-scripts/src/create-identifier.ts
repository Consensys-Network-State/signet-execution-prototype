import { agent } from './veramo/setup.js'

async function main() {
  var args = process.argv.slice(2);
  let alias = args[0] || 'default';
  const identifier = await agent.didManagerCreate({ alias })
  console.log(`New identifier create with the ${alias}`)
  console.log(JSON.stringify(identifier, null, 2))
}

main().catch(console.log)