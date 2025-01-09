
## Description

Agreements backend, using AO.

## Endpoints with samples

Take two sample Ethereum key pairs:

First key pair (Document Creator):

Private Key: `0x3183e8014bc3176f4d17430c664f8d6fd01a9da456c18362161f3b9a083f4968`
Address: `0x8164e32201D9c07564cE3DD16F01E35D323C82A4`

Second key pair (Counter-signer):

Private Key: `0x572a478f808a4be3e520c08d41ef05a80e4b8440617d9559227ac6f53bf3c4a8`
Address: `0xB94C718BFc699E4f20e9C9E66EA596A562C2D3d4`

### POST /document/create

Sample body:
```
{
    "@context": [
        "https://www.w3.org/2018/credentials/v1"
    ],
    "type": [
        "VerifiableCredential",
        "SignedAgreement"
    ],
    "id": "urn:uuid:d35238cf-8559-4451-b487-2b8d612d817e",
    "issuer": {
        "id": "did:pkh:eip155:1:0x8164e32201D9c07564cE3DD16F01E35D323C82A4"
    },
    "issuanceDate": "2025-01-09T16:57:54.299Z",
    "credentialSubject": {
        "documentHash": "0xeb3e65fb2fcbef25208795aeeed4979d3ece4fe5285683157ee99a6248ba598d",
        "timeStamp": "2025-01-09T16:57:54.299Z",
        "id": "did:pkh:eip155:1:0x8164e32201D9c07564cE3DD16F01E35D323C82A4"
    },
    "proof": {
        "type": "JwtProof2020",
        "jwt": "eyJhbGciOiJFUzI1NksifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiU2lnbmVkQWdyZWVtZW50Il0sImNyZWRlbnRpYWxTdWJqZWN0Ijp7ImRvY3VtZW50SGFzaCI6IjB4ZWIzZTY1ZmIyZmNiZWYyNTIwODc5NWFlZWVkNDk3OWQzZWNlNGZlNTI4NTY4MzE1N2VlOTlhNjI0OGJhNTk4ZCIsInRpbWVTdGFtcCI6IjIwMjUtMDEtMDlUMTY6NTc6NTQuMjk5WiIsImlkIjoiZGlkOnBraDplaXAxNTU6MToweDgxNjRlMzIyMDFEOWMwNzU2NGNFM0REMTZGMDFFMzVEMzIzQzgyQTQifX0sInN1YiI6ImRpZDpwa2g6ZWlwMTU1OjE6MHg4MTY0ZTMyMjAxRDljMDc1NjRjRTNERDE2RjAxRTM1RDMyM0M4MkE0IiwibmJmIjoxNzM2NDQxODc0LCJpc3MiOiJkaWQ6cGtoOmVpcDE1NToxOjB4ODE2NGUzMjIwMUQ5YzA3NTY0Y0UzREQxNkYwMUUzNUQzMjNDODJBNCJ9.0x1b94c718bfc699e4f20e9c9e66ea596a562c2d3d4f158c4c5cafbb56e1d5fbb5e0b89d54cde72a1c87b3d9e2c4f9b9e8b7c6d5e4f3b2a1"
    }
}
```

Expected response: 200 
```
{
	"processId": "hoUMDW52BSNzgE3vKVQbzZEYwvcqPSQjF_DWOthpBcI"
}
```
### POST /document/sign

Sample body:

```
{
    "@context": [
        "https://www.w3.org/2018/credentials/v1"
    ],
    "type": [
        "VerifiableCredential",
        "CounterSignature"
    ],
    "id": "urn:uuid:f7284cf6-98b2-4f24-9876-543210fedcba",
    "issuer": {
        "id": "did:pkh:eip155:1:0xB94C718BFc699E4f20e9C9E66EA596A562C2D3d4"
    },
    "issuanceDate": "2025-01-09T16:57:54.299Z",
    "credentialSubject": {
        "originalDocumentHash": "0xeb3e65fb2fcbef25208795aeeed4979d3ece4fe5285683157ee99a6248ba598d",
        "originalVcId": "urn:uuid:d35238cf-8559-4451-b487-2b8d612d817e",
        "timeStamp": "2025-01-09T16:57:54.299Z",
        "id": "did:pkh:eip155:1:0xB94C718BFc699E4f20e9C9E66EA596A562C2D3d4"
    },
    "proof": {
        "type": "JwtProof2020",
        "jwt": "eyJhbGciOiJFUzI1NksifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiQ291bnRlclNpZ25hdHVyZSJdLCJjcmVkZW50aWFsU3ViamVjdCI6eyJvcmlnaW5hbERvY3VtZW50SGFzaCI6IjB4ZWIzZTY1ZmIyZmNiZWYyNTIwODc5NWFlZWVkNDk3OWQzZWNlNGZlNTI4NTY4MzE1N2VlOTlhNjI0OGJhNTk4ZCIsIm9yaWdpbmFsVmNJZCI6InVybjp1dWlkOmQzNTIzOGNmLTg1NTktNDQ1MS1iNDg3LTJiOGQ2MTJkODE3ZSIsInRpbWVTdGFtcCI6IjIwMjUtMDEtMDlUMTY6NTc6NTQuMjk5WiIsImlkIjoiZGlkOnBraDplaXAxNTU6MToweDgxNjRlMzIyMDFEOWMwNzU2NGNFM0REMTZGMDFFMzVEMzIzQzgyQTQifX0sInN1YiI6ImRpZDpwa2g6ZWlwMTU1OjE6MHg4MTY0ZTMyMjAxRDljMDc1NjRjRTNERDE2RjAxRTM1RDMyM0M4MkE0IiwibmJmIjoxNzM2NDQxODc0LCJpc3MiOiJkaWQ6cGtoOmVpcDE1NToxOjB4ODE2NGUzMjIwMUQ5YzA3NTY0Y0UzREQxNkYwMUUzNUQzMjNDODJBNCJ9.0x572a478f808a4be3e520c08d41ef05a80e4b8440617d9559227ac6f53bf3c4a8"
    }
}
```

## Project setup

```bash
$ yarn install
```

## Compile and run the project

```bash
# development
$ yarn run start

# watch mode
$ yarn run start:dev

# production mode
$ yarn run start:prod
```

## Run tests

```bash
# unit tests
$ yarn run test

# e2e tests
$ yarn run test:e2e

# test coverage
$ yarn run test:cov
```

## Deployment

When you're ready to deploy your NestJS application to production, there are some key steps you can take to ensure it runs as efficiently as possible. Check out the [deployment documentation](https://docs.nestjs.com/deployment) for more information.

If you are looking for a cloud-based platform to deploy your NestJS application, check out [Mau](https://mau.nestjs.com), our official platform for deploying NestJS applications on AWS. Mau makes deployment straightforward and fast, requiring just a few simple steps:

```bash
$ yarn install -g mau
$ mau deploy
```

With Mau, you can deploy your application in just a few clicks, allowing you to focus on building features rather than managing infrastructure.

## Resources

Check out a few resources that may come in handy when working with NestJS:

- Visit the [NestJS Documentation](https://docs.nestjs.com) to learn more about the framework.
- For questions and support, please visit our [Discord channel](https://discord.gg/G7Qnnhy).
- To dive deeper and get more hands-on experience, check out our official video [courses](https://courses.nestjs.com/).
- Deploy your application to AWS with the help of [NestJS Mau](https://mau.nestjs.com) in just a few clicks.
- Visualize your application graph and interact with the NestJS application in real-time using [NestJS Devtools](https://devtools.nestjs.com).
- Need help with your project (part-time to full-time)? Check out our official [enterprise support](https://enterprise.nestjs.com).
- To stay in the loop and get updates, follow us on [X](https://x.com/nestframework) and [LinkedIn](https://linkedin.com/company/nestjs).
- Looking for a job, or have a job to offer? Check out our official [Jobs board](https://jobs.nestjs.com).

## Support

Nest is an MIT-licensed open source project. It can grow thanks to the sponsors and support by the amazing backers. If you'd like to join them, please [read more here](https://docs.nestjs.com/support).

## Stay in touch

- Author - [Kamil Myśliwiec](https://twitter.com/kammysliwiec)
- Website - [https://nestjs.com](https://nestjs.com/)
- Twitter - [@nestframework](https://twitter.com/nestframework)

## License

Nest is [MIT licensed](https://github.com/nestjs/nest/blob/master/LICENSE).
