export class CreateDocumentDto {
    title: string;
    content: string;
}

export class SignDocumentDto {
    documentId: string;
    signerId: string;
}