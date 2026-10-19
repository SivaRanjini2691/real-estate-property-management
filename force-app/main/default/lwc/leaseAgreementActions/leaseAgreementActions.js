import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import JSPDF from '@salesforce/resourceUrl/jspdf';
import getLeaseDetails from '@salesforce/apex/LeaseAgreementPdfController.getLeaseDetails';
import sendLeasePdfEmail from '@salesforce/apex/LeaseAgreementPdfController.sendLeasePdfEmail';

export default class LeaseAgreementActions extends LightningElement {
    @api recordId;

    isLoading = false;
    jsPdfLoaded = false;
    jsPdfLoadPromise;

    renderedCallback() {
        if (this.jsPdfLoadPromise) {
            return;
        }

        this.jsPdfLoadPromise = loadScript(this, JSPDF)
            .then(() => {
                if (!window.jspdf || !window.jspdf.jsPDF) {
                    throw new Error('The jsPDF library did not load correctly.');
                }

                this.jsPdfLoaded = true;
            })
            .catch((error) => {
                this.jsPdfLoadPromise = undefined;
                this.showToast(
                    'PDF Library Error',
                    this.getErrorMessage(error),
                    'error'
                );
            });
    }

    async handleDownload() {
        this.isLoading = true;

        try {
            await this.ensureJsPdfLoaded();

            const lease = await this.fetchLeaseDetails();
            const pdf = this.generatePdf(lease);

            pdf.save(this.getFileName(lease.Name));

            this.showToast(
                'Success',
                'The lease agreement PDF has been downloaded.',
                'success'
            );
        } catch (error) {
            this.showToast(
                'Unable to Download PDF',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleSendEmail() {
        this.isLoading = true;

        try {
            await this.ensureJsPdfLoaded();

            const lease = await this.fetchLeaseDetails();
            const pdf = this.generatePdf(lease);

            // jsPDF returns a data URI. Send only its Base64 payload.
            const dataUri = pdf.output('datauristring');
            const base64Pdf = dataUri.substring(dataUri.indexOf(',') + 1);

            await sendLeasePdfEmail({
                leaseId: this.recordId,
                pdfBase64: base64Pdf
            });

            this.showToast(
                'Email Sent',
                'The lease PDF was submitted for delivery to the tenant.',
                'success'
            );
        } catch (error) {
            this.showToast(
                'Unable to Send Email',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async ensureJsPdfLoaded() {
        if (this.jsPdfLoaded) {
            return;
        }

        if (!this.jsPdfLoadPromise) {
            this.jsPdfLoadPromise = loadScript(this, JSPDF)
                .then(() => {
                    if (!window.jspdf || !window.jspdf.jsPDF) {
                        throw new Error('The jsPDF library did not load correctly.');
                    }

                    this.jsPdfLoaded = true;
                })
                .catch((error) => {
                    this.jsPdfLoadPromise = undefined;
                    throw error;
                });
        }

        await this.jsPdfLoadPromise;
    }

    async fetchLeaseDetails() {
        if (!this.recordId) {
            throw new Error('Save and open a Lease Agreement record first.');
        }

        return getLeaseDetails({ leaseId: this.recordId });
    }

    generatePdf(lease) {
        const JsPDF = window.jspdf.jsPDF;
        const pdf = new JsPDF();

        const pageWidth = pdf.internal.pageSize.getWidth();
        const margin = 20;
        const textWidth = pageWidth - margin * 2;
        let y = 25;

        const addHeading = (text) => {
            pdf.setFont('helvetica', 'bold');
            pdf.setFontSize(13);
            pdf.text(text, margin, y);
            y += 9;
        };

        const addField = (label, value) => {
            pdf.setFont('helvetica', 'bold');
            pdf.setFontSize(10);
            pdf.text(`${label}:`, margin, y);

            pdf.setFont('helvetica', 'normal');

            const lines = pdf.splitTextToSize(
                String(value ?? 'Not provided'),
                textWidth - 35
            );

            pdf.text(lines, margin + 35, y);
            y += Math.max(lines.length, 1) * 6 + 3;

            if (y > 260) {
                pdf.addPage();
                y = 20;
            }
        };

        pdf.setFont('helvetica', 'bold');
        pdf.setFontSize(18);
        pdf.text('LEASE AGREEMENT', margin, y);
        y += 15;

        pdf.setFont('helvetica', 'normal');
        pdf.setFontSize(10);
        pdf.text(`Lease Reference: ${lease.Name || ''}`, margin, y);
        y += 12;

        addHeading('Tenant Details');
        addField('Tenant', lease.Tenant__r?.Name);
        addField('Tenant Email', lease.Tenant__r?.Email__c);

        y += 3;
        addHeading('Property Details');
        addField('Property', lease.Property__r?.Name);

        y += 3;
        addHeading('Lease Details');
        addField('Monthly Rent', lease.Agreed_Monthly_Rent__c);
        addField('Start Date', lease.Start_Date__c);
        addField('End Date', lease.End_Date__c);
        addField('Status', lease.Status__c);

        y += 3;
        addHeading('Terms and Conditions');

        pdf.setFont('helvetica', 'normal');
        pdf.setFontSize(10);

        const terms = pdf.splitTextToSize(
            lease.Terms__c || 'No lease terms have been entered.',
            textWidth
        );

        for (const line of terms) {
            if (y > 275) {
                pdf.addPage();
                y = 20;
            }

            pdf.text(line, margin, y);
            y += 6;
        }

        return pdf;
    }

    getFileName(leaseName) {
        const safeName = (leaseName || 'Lease_Agreement')
            .replace(/[^a-zA-Z0-9_-]/g, '_');

        return `${safeName}.pdf`;
    }

    getErrorMessage(error) {
        return (
            error?.body?.message ||
            error?.message ||
            'An unexpected error occurred.'
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}