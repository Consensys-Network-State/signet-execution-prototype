
## Description

Agreements backend, using AO.

## Proposed Overall Flow

1. Creator uses UI to draft agreement.
2. Creator configures requested signature addresses.
3. Creator signs off for publishing, generating a VC.
4. UI Encrypts credentialSubject.document portion of the VC with public key of signer and sends to backend.
5. Backend spawns AO actor with agreement code and stores the VC.
6. AO actor verifies VC integrity and stores it.
7. Creator sends a generated signature link to the signer.
8. Signer loads link which renders UI that fetches document VC from AO through backend.
9. Signer decrypts VC using wallet.
10. Signer reviews the decrypted document and signs a new signature VC against the document VC.
11. UI sends the VC to the backend and thus AO.
12. AO actor verified signature VC integrity and marks the document as signed.
13. UI that was polling backend for completion detects completion and marks the document as signed.

![image](https://github.com/user-attachments/assets/bfec7f77-d609-4232-8156-2517a048119f)

Source: https://www.figma.com/board/FLZ211bOwAS2eehIbIHPRw/Agreements-End-to-End-MVP?node-id=1-467&t=isZzmkmUNBsStMJ2-1

## Endpoints with samples

Take two sample Ethereum key pairs:

First key pair (Document Creator):

Private Key: `0x3183e8014bc3176f4d17430c664f8d6fd01a9da456c18362161f3b9a083f4968`
Address: `0x8164e32201D9c07564cE3DD16F01E35D323C82A4`

Second key pair (Counter-signer):

Private Key: `0x572a478f808a4be3e520c08d41ef05a80e4b8440617d9559227ac6f53bf3c4a8`
Address: `0xB94C718BFc699E4f20e9C9E66EA596A562C2D3d4`

### POST /documents

Sample body:
```
{"id":"468cd235-f225-4e8f-b999-71c954f3bbad","issuer":{"id":"did:pkh:eip155:1:0x1e8564A52fc67A68fEe78Fc6422F19c07cFae198"},"@context":["https://www.w3.org/2018/credentials/v1"],"type":["VerifiableCredential","Agreement"],"issuanceDate":"2025-01-20T17:53:04.220Z","credentialSubject":{"id":"did:pkh:eip155:1:0x1e8564A52fc67A68fEe78Fc6422F19c07cFae198","document":"W3siaWQiOiJkOWQ1OTJhNC1hZTQ3LTQzOWEtODIyMC1kMTYxNTNiMmNmYzUiLCJ0eXBlIjoicGFyYWdyYXBoIiwicHJvcHMiOnsidGV4dENvbG9yIjoiZGVmYXVsdCIsImJhY2tncm91bmRDb2xvciI6ImRlZmF1bHQiLCJ0ZXh0QWxpZ25tZW50IjoibGVmdCJ9LCJjb250ZW50IjpbeyJ0eXBlIjoidGV4dCIsInRleHQiOiJURVNUIERPQ1VNRU5UXG4iLCJzdHlsZXMiOnsiYm9sZCI6dHJ1ZX19XSwiY2hpbGRyZW4iOltdfSx7ImlkIjoiZTk5YTI4MjAtZTVhZS00ZWE1LTkwMGQtN2RmYTdjYzQ4NjY2IiwidHlwZSI6InBhcmFncmFwaCIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiVGhlIEdyYW50IFJlY2lwaWVudCBoYXMgYmVlbiBzZWxlY3RlZCBieSB0aGUgRm91bmRhdGlvbiBEZXNpZ25hdGVkIFRva2VuIEFsbG9jYXRvciA8RFdBVCBOYW1lPiAoIiwic3R5bGVzIjp7fX0seyJ0eXBlIjoidGV4dCIsInRleHQiOiLigJxUb2tlbiBBbGxvY2F0b3LigJ0iLCJzdHlsZXMiOnsiYm9sZCI6dHJ1ZX19LHsidHlwZSI6InRleHQiLCJ0ZXh0IjoiKSB3aXRoIGFkZHJlc3MgPFNlbGVjdCBEMyBJRD4gdG8gcmVjZWl2ZSBhIGdyYW50IHN1YmplY3QgYW5kIGluIGFjY29yZGFuY2Ugd2l0aCB0aGUgdGVybXMgYW5kIGNvbmRpdGlvbnMgb2YgdGhpcyBBZ3JlZW1lbnQuXG4iLCJzdHlsZXMiOnt9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6ImRkMGY0NDFhLTkwZjYtNGQ1NC04M2JhLTc3NmQ4MDBjYWJiOCIsInR5cGUiOiJwYXJhZ3JhcGgiLCJwcm9wcyI6eyJ0ZXh0Q29sb3IiOiJkZWZhdWx0IiwiYmFja2dyb3VuZENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOlt7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IlRIRVJFRk9SRSwgdGhlIHBhcnRpZXMgYWdyZWUgYXMgZm9sbG93czpcbiIsInN0eWxlcyI6e319XSwiY2hpbGRyZW4iOltdfSx7ImlkIjoiYTllOTgwMWUtZjA1Mi00NDY3LTk5YjUtNDIwZjVhYjBlMDdhIiwidHlwZSI6InBhcmFncmFwaCIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiMS4gR1JBTlQgUkVDSVBJRU5UIEFDVElWSVRJRVNcbiIsInN0eWxlcyI6eyJib2xkIjp0cnVlfX1dLCJjaGlsZHJlbiI6W119LHsiaWQiOiIzY2IwYTE4Yy0wZTZiLTRhMjMtYjIxOS01NDg1N2MwODg4ZDIiLCJ0eXBlIjoicGFyYWdyYXBoIiwicHJvcHMiOnsidGV4dENvbG9yIjoiZGVmYXVsdCIsImJhY2tncm91bmRDb2xvciI6ImRlZmF1bHQiLCJ0ZXh0QWxpZ25tZW50IjoibGVmdCJ9LCJjb250ZW50IjpbeyJ0eXBlIjoidGV4dCIsInRleHQiOiIxLjEgIiwic3R5bGVzIjp7fX0seyJ0eXBlIjoidGV4dCIsInRleHQiOiJHcmFudHMiLCJzdHlsZXMiOnsidW5kZXJsaW5lIjp0cnVlfX0seyJ0eXBlIjoidGV4dCIsInRleHQiOiIuIEZvdW5kYXRpb24gYW5kIEdyYW50IFJlY2lwaWVudCBhcmUgZW50ZXJpbmcgaW50byB0aGlzIEFncmVlbWVudCBpbiBjb25uZWN0aW9uIHdpdGggUkZQIzogPFdSRlAgTnVtYmVyPiAsIGFzIHNldCBmb3J0aCBhdCA8U2VsZWN0IEQzIExpbms+ICwgd2hpY2ggZGVzY3JpYmVzIHRoZSBzcGVjaWZpYyBhY3Rpdml0aWVzIHRvIGJlIHBlcmZvcm1lZCBieSBHcmFudCBSZWNpcGllbnQgKHRoZSIsInN0eWxlcyI6e319LHsidHlwZSI6InRleHQiLCJ0ZXh0IjoiIOKAnEdyYW504oCdIiwic3R5bGVzIjp7ImJvbGQiOnRydWV9fSx7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IikuXG4iLCJzdHlsZXMiOnt9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6IjFkMGFiMTJkLWU0NDAtNDA5OC04NGVjLWYxOTUxODZmMGZlNyIsInR5cGUiOiJwYXJhZ3JhcGgiLCJwcm9wcyI6eyJ0ZXh0Q29sb3IiOiJkZWZhdWx0IiwiYmFja2dyb3VuZENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOlt7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IjEuMiAiLCJzdHlsZXMiOnt9fSx7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IlBlcmZvcm1hbmNlIG9mIEdyYW50IFJlY2lwaWVudCBBY3Rpdml0aWVzLiIsInN0eWxlcyI6eyJ1bmRlcmxpbmUiOnRydWV9fSx7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IiBHcmFudCBSZWNpcGllbnQgd2lsbCBwZXJmb3JtIHRoZSBhY3Rpdml0aWVzIGRlc2NyaWJlZCBpbiB0aGUgR3JhbnQgKHRoZSAiLCJzdHlsZXMiOnt9fSx7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IuKAnEdyYW50IFJlY2lwaWVudCBBY3Rpdml0aWVz4oCdIiwic3R5bGVzIjp7ImJvbGQiOnRydWV9fSx7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IikgaW4gYWNjb3JkYW5jZSB3aXRoIHRoZSB0ZXJtcyBhbmQgY29uZGl0aW9ucyBzZXQgZm9ydGggaW4gZWFjaCBzdWNoIEdyYW50IGFuZCB0aGlzIEFncmVlbWVudCBhbmQgd2l0aCBhbnkgYXBwbGljYWJsZSBsYXdzLiBHcmFudCBSZWNpcGllbnQgd2lsbCBub3QgcGFydGljaXBhdGUgaW4gb3IgZW5jb3VyYWdlIGFueSBhdHRhY2tzIG9uIHRoZSBXb3JrVG9rZW4gQ29tbXVuaXR5LCBpbmNsdWRpbmcgYnV0IG5vdCBsaW1pdGVkIHRvOiIsInN0eWxlcyI6e319XSwiY2hpbGRyZW4iOltdfSx7ImlkIjoiN2EyYWM1MWYtZWM4Yy00ZDU1LWFjYzQtNzhiNmZjZTk5OGQ3IiwidHlwZSI6ImJ1bGxldExpc3RJdGVtIiwicHJvcHMiOnsidGV4dENvbG9yIjoiZGVmYXVsdCIsImJhY2tncm91bmRDb2xvciI6ImRlZmF1bHQiLCJ0ZXh0QWxpZ25tZW50IjoibGVmdCJ9LCJjb250ZW50IjpbeyJ0eXBlIjoidGV4dCIsInRleHQiOiJUZWNobmljYWwgYXR0YWNrcywgaGFja2luZywgdGhlZnQgb2YgdGhlIFdPUksgQ29tbXVuaXR5IGZ1bmRzLCBvciBmcmF1ZCwiLCJzdHlsZXMiOnt9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6IjAzNTBlOTEwLWRmYzQtNDdjZC1iYjcxLTQxYmZjOWFkYTlmMCIsInR5cGUiOiJidWxsZXRMaXN0SXRlbSIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiQW55IGNvbmR1Y3QgcmVhc29uYWJseSBhbnRpY2lwYXRlZCB0byBjYXVzZSBoYXJtIHRvIHRoZSBXT1JLIENvbW11bml0eSBvciB0aGUgRm91bmRhdGlvbiwgb3IiLCJzdHlsZXMiOnt9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6ImNkNjcwNmYxLWEwNjgtNDgzZS1iYjJjLTFkYzEyNTBkY2Y5NiIsInR5cGUiOiJidWxsZXRMaXN0SXRlbSIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiQW55IG90aGVyIGFjdGl2aXR5IHRoYXQgRm91bmRhdGlvbiBjb25zaWRlcnMgdG8gYmUgbWFsaWNpb3VzIG9yIHVubGF3ZnVsIGFjdGl2aXR5LCBpbiBpdHMgc29sZSBkaXNjcmV0aW9uLiIsInN0eWxlcyI6e319XSwiY2hpbGRyZW4iOltdfSx7ImlkIjoiYzU2ZTkwZmEtYjM2Zi00MDI2LTkzNmMtNjUzMmRiMWYyNGYxIiwidHlwZSI6InBhcmFncmFwaCIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W10sImNoaWxkcmVuIjpbXX0seyJpZCI6ImE3YjQ2NjhiLWQ0NjUtNGU3Zi05MGZlLWQwYjA3YWE2MmViNyIsInR5cGUiOiJwYXJhZ3JhcGgiLCJwcm9wcyI6eyJ0ZXh0Q29sb3IiOiJkZWZhdWx0IiwiYmFja2dyb3VuZENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOlt7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IjIuIEdSQU5UIERJU1RSSUJVVElPTlxuIiwic3R5bGVzIjp7ImJvbGQiOnRydWV9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6ImQxMmM0NmQ5LTUwM2MtNGRlYS05YzI0LTAzMjMwM2JkMzM1YiIsInR5cGUiOiJwYXJhZ3JhcGgiLCJwcm9wcyI6eyJ0ZXh0Q29sb3IiOiJkZWZhdWx0IiwiYmFja2dyb3VuZENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOlt7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IlRoZSBUb2tlbiBBbGxvY2F0b3Igd2lsbCBwYXkgR3JhbnQgUmVjaXBpZW50IG9uIGJlaGFsZiBvZiB0aGUgRm91bmRhdGlvbiB0aGUgYW1vdW50cyBzcGVjaWZpZWQgaW4gZWFjaCBHcmFudCBpbiBhY2NvcmRhbmNlIHdpdGggdGhlIHRlcm1zIHNldCBmb3J0aCBpbiAiLCJzdHlsZXMiOnt9fSx7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IlNDSEVEVUxFIEEiLCJzdHlsZXMiOnsiYm9sZCI6dHJ1ZX19LHsidHlwZSI6InRleHQiLCJ0ZXh0IjoiICh0aGUgIiwic3R5bGVzIjp7fX0seyJ0eXBlIjoidGV4dCIsInRleHQiOiLigJxQYXltZW50IFNjaGVkdWxl4oCdIiwic3R5bGVzIjp7ImJvbGQiOnRydWV9fSx7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IikgdGhlcmVpbiB1c2luZzoiLCJzdHlsZXMiOnt9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6IjdjYTMxM2UyLTQ3MmQtNDllNi05OWEyLWIyMmY2NTYwODFjOCIsInR5cGUiOiJwYXJhZ3JhcGgiLCJwcm9wcyI6eyJ0ZXh0Q29sb3IiOiJkZWZhdWx0IiwiYmFja2dyb3VuZENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOltdLCJjaGlsZHJlbiI6W119LHsiaWQiOiIxZmUxNTg3NS0wODQwLTQyMjgtOTZhYS0zZTRjNmNiNjk5ODYiLCJ0eXBlIjoic2FibGllciIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJ0ZXh0QWxpZ25tZW50IjoibGVmdCIsInNoYXBlIjoibW9udGhseSIsImNoYWluIjoxLCJ0b2tlbiI6IiIsImFtb3VudCI6MCwiZHVyYXRpb24iOjEsImZpcnN0VW5sb2NrIjoiZGVmYXVsdCJ9LCJjb250ZW50IjpbeyJ0eXBlIjoidGV4dCIsInRleHQiOiJUZXN0Iiwic3R5bGVzIjp7fX1dLCJjaGlsZHJlbiI6W119LHsiaWQiOiI2ZTM0NDdjMy0yOWRmLTRmNWYtYTdlMy05Y2MwMDU4NDM2MTIiLCJ0eXBlIjoicGFyYWdyYXBoIiwicHJvcHMiOnsidGV4dENvbG9yIjoiZGVmYXVsdCIsImJhY2tncm91bmRDb2xvciI6ImRlZmF1bHQiLCJ0ZXh0QWxpZ25tZW50IjoibGVmdCJ9LCJjb250ZW50IjpbXSwiY2hpbGRyZW4iOltdfSx7ImlkIjoiYjIyY2JmMGUtZjY4OC00ODA3LTgxZjQtM2ZlODM0ZmM4MzVmIiwidHlwZSI6InBhcmFncmFwaCIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiQWxsIG90aGVyIGFtb3VudHMgc2V0IGZvcnRoIGluIHRoZSBHcmFudCwgaWYgYW55LCBhcmUgc3RhdGVkIGluIGFuZCBhcmUgcGF5YWJsZSBpbiBXT1JLLiBUaGUgcGFydGllcyB3aWxsIHVzZSB0aGVpciByZXNwZWN0aXZlIGNvbW1lcmNpYWxseSByZWFzb25hYmxlIGVmZm9ydHMgdG8gcHJvbXB0bHkgcmVzb2x2ZSBhbnkgcGF5bWVudCBkaXNwdXRlcy4gR3JhbnQgUmVjaXBpZW50IHVuZGVyc3RhbmRzIGFuZCBhY2tub3dsZWRnZXMgdGhhdDoiLCJzdHlsZXMiOnt9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6Ijg2OGNmYjU4LWEzMTQtNDhkMi04NjA4LWEyNzE5NjU2MWVhOCIsInR5cGUiOiJidWxsZXRMaXN0SXRlbSIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiRm91bmRhdGlvbiB3aWxsIG5vdCBiZSBpbnZvbHZlZCBpbiB0aGUgb3BlcmF0aW9uIG9mIGFueSBHcmFudCBSZWNpcGllbnQgQWN0aXZpdGllczsiLCJzdHlsZXMiOnt9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6Ijg5MGQwYTVjLWZmNWYtNGE1ZC05NWM4LTZmMzdiZGEzNmVlZSIsInR5cGUiOiJidWxsZXRMaXN0SXRlbSIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiQnkgcHJvdmlkaW5nIHRoZSBHcmFudCwgRm91bmRhdGlvbiBpcyBvbmx5IGdyYW50aW5nIFdPUksgdG8gR3JhbnQgUmVjaXBpZW50IGFuZCBpcyBub3QgY29uZHVjdGluZyBhbnkgR3JhbnQgUmVjaXBpZW50IEFjdGl2aXRpZXM7Iiwic3R5bGVzIjp7fX1dLCJjaGlsZHJlbiI6W119LHsiaWQiOiIzMDgzMWFiNy0zZjU3LTRmMDMtYmYyNi1jNzg4ZGE5MGU1YmUiLCJ0eXBlIjoiYnVsbGV0TGlzdEl0ZW0iLCJwcm9wcyI6eyJ0ZXh0Q29sb3IiOiJkZWZhdWx0IiwiYmFja2dyb3VuZENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOlt7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IkZvdW5kYXRpb24gaXMgbm90LCBhbmQgd2lsbCBub3QgYmUsIHJlZ2lzdGVyZWQgYXMgYSB2aXJ0dWFsIGFzc2V0IHNlcnZpY2UgcHJvdmlkZXIgdW5kZXIgdGhlIFZpcnR1YWwgQXNzZXRzIFNlcnZpY2VzIFByb3ZpZGVycyBBY3Qgb2YgdGhlIFtKdXJpc2RpY3Rpb25dIGFuZCB0aGUgV09SSyB0b2tlbnMgaGF2ZSBub3QgYmVlbiwgYW5kIHdpbGwgbm90IGJlLCByZWdpc3RlcmVkIHdpdGggdGhlIFtKdXJpc2RpY3Rpb25dIE1vbmV0YXJ5IEF1dGhvcml0eTsgYW5kIiwic3R5bGVzIjp7fX1dLCJjaGlsZHJlbiI6W119LHsiaWQiOiJhOTk3OGJkMy1hNmMwLTQ4MzYtYWQ1Mi0zOTJmY2FmZDMwY2UiLCJ0eXBlIjoiYnVsbGV0TGlzdEl0ZW0iLCJwcm9wcyI6eyJ0ZXh0Q29sb3IiOiJkZWZhdWx0IiwiYmFja2dyb3VuZENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOlt7InR5cGUiOiJ0ZXh0IiwidGV4dCI6IlRoaXMgQWdyZWVtZW50IGRvZXMgbm90IGNvbnN0aXR1dGUgYSBzYWxlIG9mIHZpcnR1YWwgYXNzZXRzIHRvIHRoZSBwdWJsaWMuIiwic3R5bGVzIjp7fX1dLCJjaGlsZHJlbiI6W119LHsiaWQiOiI0ZTAyMTUyZC1iMzZhLTQ4ZGMtYTQwNy04YmM2NTNkZGIwNGYiLCJ0eXBlIjoicGFyYWdyYXBoIiwicHJvcHMiOnsidGV4dENvbG9yIjoiZGVmYXVsdCIsImJhY2tncm91bmRDb2xvciI6ImRlZmF1bHQiLCJ0ZXh0QWxpZ25tZW50IjoibGVmdCJ9LCJjb250ZW50IjpbXSwiY2hpbGRyZW4iOltdfSx7ImlkIjoiN2YzOGZkYzMtNjNiZS00YjVlLTk5ZGUtYWQyMTZjYzZlMmZmIiwidHlwZSI6InBhcmFncmFwaCIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiSU4gV0lUTkVTUyBXSEVSRU9GLCB0aGUgR3JhbnQgUmVjaXBpZW50IGhhcyBleGVjdXRlZCB0aGlzIEFncmVlbWVudCBvbiB0aGUgZGF0ZSBmaXJzdCB3cml0dGVuIGFib3ZlLlxuIiwic3R5bGVzIjp7fX1dLCJjaGlsZHJlbiI6W119LHsiaWQiOiI0ZTJhN2YyYy1hY2ZiLTQ1NWQtYjU1MC1jNGRiMGJmZGQ0ODIiLCJ0eXBlIjoic2lnbmF0dXJlIiwicHJvcHMiOnsidGV4dENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOltdLCJjaGlsZHJlbiI6W119LHsiaWQiOiIxNTEzMzllMy0yNDhmLTRjYTYtYThmZi1jNGJhYTdkYTBlOTMiLCJ0eXBlIjoicGFyYWdyYXBoIiwicHJvcHMiOnsidGV4dENvbG9yIjoiZGVmYXVsdCIsImJhY2tncm91bmRDb2xvciI6ImRlZmF1bHQiLCJ0ZXh0QWxpZ25tZW50IjoibGVmdCJ9LCJjb250ZW50IjpbeyJ0eXBlIjoidGV4dCIsInRleHQiOiJOYW1lOiBTdXBDMEQzUiIsInN0eWxlcyI6e319XSwiY2hpbGRyZW4iOltdfSx7ImlkIjoiNzBlMDg5ZGEtYmFkZi00N2QwLWEyYzctMGRmODE3N2VmYWQ2IiwidHlwZSI6InBhcmFncmFwaCIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiVGl0bGU6IFRlY2ggTGVhZCIsInN0eWxlcyI6e319XSwiY2hpbGRyZW4iOltdfSx7ImlkIjoiNDgwNmZkYmUtYTJhYy00MTVkLWFiZDktYzQ2OWU1Mzk2Yzc5IiwidHlwZSI6InBhcmFncmFwaCIsInByb3BzIjp7InRleHRDb2xvciI6ImRlZmF1bHQiLCJiYWNrZ3JvdW5kQ29sb3IiOiJkZWZhdWx0IiwidGV4dEFsaWdubWVudCI6ImxlZnQifSwiY29udGVudCI6W3sidHlwZSI6InRleHQiLCJ0ZXh0IjoiXG4iLCJzdHlsZXMiOnt9fV0sImNoaWxkcmVuIjpbXX0seyJpZCI6ImY2ZGZjZDhkLTliNmItNDA4Mi05NmFhLWRjYmU4MTQyNDVkOCIsInR5cGUiOiJwYXJhZ3JhcGgiLCJwcm9wcyI6eyJ0ZXh0Q29sb3IiOiJkZWZhdWx0IiwiYmFja2dyb3VuZENvbG9yIjoiZGVmYXVsdCIsInRleHRBbGlnbm1lbnQiOiJsZWZ0In0sImNvbnRlbnQiOltdLCJjaGlsZHJlbiI6W119XQ==","timeStamp":"2025-01-20T17:53:04.222Z","signatories":["0x057ef20Ed09fc34Da5af791376F4447ba0B8cDE6"]},"proof":{"verificationMethod":"did:pkh:eip155:1:0x1e8564A52fc67A68fEe78Fc6422F19c07cFae198#blockchainAccountId","created":"2025-01-20T17:53:04.220Z","proofPurpose":"assertionMethod","type":"EthereumEip712Signature2021","proofValue":"0x9efe565518e797b38615da9eacd01cda9ad68d81c941f0cac06e33ad3e90a11b63d2eb6919c4fbf57de3f3020b7ded1047d66de38df08899ba77271df23fc7d71c","eip712":{"domain":{"chainId":1,"name":"VerifiableCredential","version":"1"},"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"}],"CredentialSubject":[{"name":"document","type":"string"},{"name":"id","type":"string"},{"name":"signatories","type":"string[]"},{"name":"timeStamp","type":"string"}],"Issuer":[{"name":"id","type":"string"}],"Proof":[{"name":"created","type":"string"},{"name":"proofPurpose","type":"string"},{"name":"type","type":"string"},{"name":"verificationMethod","type":"string"}],"VerifiableCredential":[{"name":"@context","type":"string[]"},{"name":"credentialSubject","type":"CredentialSubject"},{"name":"id","type":"string"},{"name":"issuanceDate","type":"string"},{"name":"issuer","type":"Issuer"},{"name":"proof","type":"Proof"},{"name":"type","type":"string[]"}]},"primaryType":"VerifiableCredential"}}}
```

Expected response: 200 
```
{
	"processId": "hoUMDW52BSNzgE3vKVQbzZEYwvcqPSQjF_DWOthpBcI"
}
```
### POST /documents/:id/sign

Sample body:

```
{"id":"bec67f93-3eb3-4049-92b1-2da610199f93","issuer":{"id":"did:pkh:eip155:1:0x057ef20Ed09fc34Da5af791376F4447ba0B8cDE6"},"@context":["https://www.w3.org/2018/credentials/v1"],"type":["VerifiableCredential","SignedAgreement"],"issuanceDate":"2025-01-20T17:53:56.492Z","credentialSubject":{"id":"did:pkh:eip155:1:0x057ef20Ed09fc34Da5af791376F4447ba0B8cDE6","documentHash":"0xdbfb72b26d40750ece76dedff097277f0e37f62b10eab12371a1b865be71de89","timeStamp":"2025-01-20T17:53:56.496Z"},"proof":{"verificationMethod":"did:pkh:eip155:1:0x057ef20Ed09fc34Da5af791376F4447ba0B8cDE6#blockchainAccountId","created":"2025-01-20T17:53:56.492Z","proofPurpose":"assertionMethod","type":"EthereumEip712Signature2021","proofValue":"0xb3889b39721aa3ece0fc0995b2629ba4a873d66992d295f5d2ff22e2d33fab5a6147801d396a3a4db77b9e17a4fe1d6d7dc577a4225a8a0df1c095a09ab6b4bc1b","eip712":{"domain":{"chainId":1,"name":"VerifiableCredential","version":"1"},"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"}],"CredentialSubject":[{"name":"documentHash","type":"string"},{"name":"id","type":"string"},{"name":"timeStamp","type":"string"}],"Issuer":[{"name":"id","type":"string"}],"Proof":[{"name":"created","type":"string"},{"name":"proofPurpose","type":"string"},{"name":"type","type":"string"},{"name":"verificationMethod","type":"string"}],"VerifiableCredential":[{"name":"@context","type":"string[]"},{"name":"credentialSubject","type":"CredentialSubject"},{"name":"id","type":"string"},{"name":"issuanceDate","type":"string"},{"name":"issuer","type":"Issuer"},{"name":"proof","type":"Proof"},{"name":"type","type":"string[]"}]},"primaryType":"VerifiableCredential"}}}
```

### GET /documents/:id

To fetch an existing document at any point after creation to see the content and the status of signature submission

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
