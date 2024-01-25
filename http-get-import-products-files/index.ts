import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { BlobSASPermissions, StorageSharedKeyCredential, generateBlobSASQueryParameters, BlobSASSignatureValues } from "@azure/storage-blob";

const containerName = 'uploaded';
const accountName = process.env.STORAGE_ACCOUNT_NAME || '';
const accountKey = process.env.STORAGE_ACCOUNT_KEY || '';

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    const blobName = req.params.name;
    const permissions = BlobSASPermissions.parse("rw");
    const sharedKeyCredential = new StorageSharedKeyCredential(accountName, accountKey);
    const blobSASSignatureValues: BlobSASSignatureValues = {
        containerName,
        permissions,
        blobName,
        startsOn: new Date(),
        expiresOn: new Date(new Date().valueOf() + (1 * 60 * 60 * 1000)),
    }

    const blobSAS = generateBlobSASQueryParameters(
        blobSASSignatureValues,
        sharedKeyCredential
    ).toString();

    context.res = {
        status: 200,
        body: {
            blobSAS: blobSAS
        }
    };
};

export default httpTrigger;