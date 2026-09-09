import nodemailer from 'nodemailer';

export class EmailService {
  private static transporter: nodemailer.Transporter | null = null;
  private static testAccount: any = null;

  private static async getTransporter(): Promise<nodemailer.Transporter> {
    if (this.transporter) return this.transporter;

    const smtpService = process.env.SMTP_SERVICE;
    const smtpHost = process.env.SMTP_HOST;
    const smtpPort = process.env.SMTP_PORT || '587';
    const smtpUser = process.env.SMTP_USER;
    const smtpPass = process.env.SMTP_PASS;

    if (smtpUser && smtpPass) {
      if (smtpService === 'gmail' || smtpHost === 'smtp.gmail.com') {
        console.log(`[Email Service] Setting up Gmail SMTP mailer for ${smtpUser}...`);
        this.transporter = nodemailer.createTransport({
          service: 'gmail',
          auth: {
            user: smtpUser,
            pass: smtpPass,
          },
        });
        return this.transporter;
      } else if (smtpHost) {
        console.log(`[Email Service] Setting up custom SMTP mailer (${smtpHost}:${smtpPort})...`);
        this.transporter = nodemailer.createTransport({
          host: smtpHost,
          port: parseInt(smtpPort),
          secure: smtpPort === '465',
          auth: {
            user: smtpUser,
            pass: smtpPass,
          },
        });
        return this.transporter;
      }
    }

    try {
      console.log('[Email Service] No SMTP credentials configured. Setting up Ethereal test account...');
      this.testAccount = await nodemailer.createTestAccount();
      
      this.transporter = nodemailer.createTransport({
        host: 'smtp.ethereal.email',
        port: 587,
        secure: false,
        auth: {
          user: this.testAccount.user,
          pass: this.testAccount.pass,
        },
      });

      console.log(`[Email Service] Test account created: ${this.testAccount.user}`);
      return this.transporter;
    } catch (error) {
      console.error('[Email Service] Failed to create test account, falling back to console-only mode:', error);
      this.transporter = nodemailer.createTransport({
        jsonTransport: true
      });
      return this.transporter;
    }
  }

  public static async sendVerificationCode(email: string, code: string): Promise<string | null> {
    console.log(`[Email Service] Preparing verification email for ${email} with code ${code}...`);
    
    try {
      const transporter = await this.getTransporter();
      const sender = process.env.SMTP_FROM || process.env.SMTP_USER || '"Remell Assistant" <no-reply@remell.ai>';

      const mailOptions = {
        from: sender,
        to: email,
        subject: 'Your Remell Registration Verification Code',
        text: `Hello!\n\nThank you for signing up for Remell AI Memory Assistant. Use the verification code below to verify your account:\n\n${code}\n\nThis code will expire in 5 minutes.\n\nKeep focusing!\nThe Remell Team`,
        html: `
          <div style="font-family: 'Inter', Helvetica, Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 16px; background-color: #ffffff; color: #1e293b;">
            <div style="text-align: center; margin-bottom: 24px;">
              <h2 style="margin: 0; color: #3b82f6; font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">Remell AI</h2>
              <span style="font-size: 12px; color: #64748b; font-weight: 500;">Memory & Focus Assistant</span>
            </div>
            <p style="font-size: 15px; line-height: 1.6; color: #334155;">Hello,</p>
            <p style="font-size: 15px; line-height: 1.6; color: #334155;">Thank you for registering on Remell! To complete your sign-up, please use the following one-time verification code:</p>
            <div style="text-align: center; margin: 32px 0;">
              <div style="display: inline-block; padding: 12px 32px; background-color: #f1f5f9; border-radius: 12px; font-size: 28px; font-weight: 800; letter-spacing: 4px; color: #1e293b; border: 1.5px solid #cbd5e1;">
                ${code}
              </div>
            </div>
            <p style="font-size: 13px; line-height: 1.5; color: #64748b; margin-top: 24px;">This code is valid for <strong>5 minutes</strong>. If you did not request this code, you can safely ignore this email.</p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
            <p style="font-size: 12px; color: #94a3b8; text-align: center; margin: 0;">&copy; 2026 Remell AI. All rights reserved.</p>
          </div>
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      
      const previewUrl = nodemailer.getTestMessageUrl(info);
      console.log(`[Email Service] Verification email dispatched successfully.`);
      console.log(`[Email Service] Verification code: ${code}`);
      if (previewUrl) {
        console.log(`[Email Service] View Ethereal Mailbox: ${previewUrl}`);
        return previewUrl;
      }
      return null;
    } catch (error) {
      console.error('[Email Service] Error sending mail, fallback printed code to console:', error);
      console.log(`[Email Service] Verification code (Fallback): ${code}`);
      return null;
    }
  }
}