import { google } from 'googleapis';
import { Readable } from 'stream';

const CLIENT_ID = process.env.GMAIL_OAUTH_CLIENT_ID;
const CLIENT_SECRET = process.env.GMAIL_OAUTH_CLIENT_SECRET;
const REFRESH_TOKEN = process.env.GMAIL_OAUTH_REFRESH_TOKEN;
const REDIRECT_URI = 'https://developers.google.com/oauthplayground';

const oAuth2Client = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET, REDIRECT_URI);

if (REFRESH_TOKEN) {
    oAuth2Client.setCredentials({ refresh_token: REFRESH_TOKEN });
}

export async function sendEmailWithAttachment(
    toEmail: string,
    subject: string,
    body: string,
    attachmentBuffer: Buffer,
    filename: string
) {
    if (!REFRESH_TOKEN) {
        throw new Error('Gmail Refresh Token not configured');
    }

    const gmail = google.gmail({ version: 'v1', auth: oAuth2Client });

    const boundary = 'foo_bar_baz';
    const messageParts = [
        `From: "RiceAgent" <me>`,
        `To: ${toEmail}`,
        `Subject: ${subject}`,
        `MIME-Version: 1.0`,
        `Content-Type: multipart/mixed; boundary="${boundary}"`,
        ``,
        `--${boundary}`,
        `Content-Type: text/plain; charset="UTF-8"`,
        `Content-Transfer-Encoding: 7bit`,
        ``,
        body,
        ``,
        `--${boundary}`,
        `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet; name="${filename}"`,
        `Content-Disposition: attachment; filename="${filename}"`,
        `Content-Transfer-Encoding: base64`,
        ``,
        attachmentBuffer.toString('base64'),
        ``,
        `--${boundary}--`,
    ];

    const message = messageParts.join('\n');
    const encodedMessage = Buffer.from(message)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');

    const res = await gmail.users.messages.send({
        userId: 'me',
        requestBody: {
            raw: encodedMessage,
        },
    });

    return res.data;
}
