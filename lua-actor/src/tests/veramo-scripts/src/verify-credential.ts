import { agent } from './veramo/setup.js'

async function main() {
  const result = await agent.verifyCredential({
    credential: {
      credentialSubject: {
        you: "Rock",
        id: "did:web:example.com"
      },
      issuer: {
        id: "did:ethr:sepolia:0x02c63efe3dc707f6e3d323f11e40cf07578b2ab9aee1635e6ee676f6da09f1598d"
      },
      type: [
        "VerifiableCredential"
      ],
      '@context': [
        "https://www.w3.org/2018/credentials/v1"
      ],
      issuanceDate: "2024-10-17T15:34:36.000Z",
      proof: {
        type: "JwtProof2020",
        jwt: "eyJhbGciOiJFUzI1NksiLCJ0eXAiOiJKV1QifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIl0sImNyZWRlbnRpYWxTdWJqZWN0Ijp7InlvdSI6IlJvY2sifX0sInN1YiI6ImRpZDp3ZWI6ZXhhbXBsZS5jb20iLCJuYmYiOjE3MjkxNzkyNzYsImlzcyI6ImRpZDpldGhyOnNlcG9saWE6MHgwMmM2M2VmZTNkYzcwN2Y2ZTNkMzIzZjExZTQwY2YwNzU3OGIyYWI5YWVlMTYzNWU2ZWU2NzZmNmRhMDlmMTU5OGQifQ.GuekQo4s7zga1Ntu7C3vOutKG9Qk6x0O-hgm1NF4QOQslZ9eDEW27I7miCd_nFhQUtoO47r0auyds0UDrB2QoA"
      }
    },
  })
  console.log(`Credential verified`, result.verified)
}

main().catch(console.log)