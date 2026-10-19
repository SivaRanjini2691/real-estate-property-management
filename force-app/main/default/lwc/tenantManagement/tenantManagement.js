import { LightningElement } from 'lwc';

import getTenants
    from '@salesforce/apex/TenantController.getTenants';

import createTenant
    from '@salesforce/apex/TenantController.createTenant';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TenantManagement extends LightningElement {
    tenants = [];
    searchKey = '';
    isLoading = false;
    showNewTenantForm = false;
    isSaving = false;

    tenantName = '';
    phoneNumber = '';
    emailAddress = '';

    columns = [
        {
            label: 'Tenant Name',
            fieldName: 'Name',
            type: 'text'
        },
        {
            label: 'Phone',
            fieldName: 'Phone_Number__c',
            type: 'phone'
        },
        {
            label: 'Email',
            fieldName: 'Email__c',
            type: 'email'
        },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        }
    ];

    connectedCallback() {
        this.loadTenants();
    }

    get hasTenants() {
        return this.tenants.length > 0;
    }

    get isSaveDisabled() {
        return this.isSaving;
    }
handleSearchChange(event) {
    this.searchKey = event.target.value;
    this.loadTenants();
}

async loadTenants() {
    this.isLoading = true;

    try {
        const result = await getTenants({
            searchKey: this.searchKey || ''
        });

        this.tenants = result || [];

        console.log('Tenants loaded:', this.tenants.length);
    } catch (error) {
        this.tenants = [];

        this.showToast(
            'Error loading tenants',
            this.getErrorMessage(error),
            'error'
        );
    } finally {
        this.isLoading = false;
    }
}

    handleNewTenant() {
        this.resetForm();
        this.showNewTenantForm = true;
    }

    handleCloseForm() {
        if (this.isSaving) {
            return;
        }

        this.showNewTenantForm = false;
        this.resetForm();
    }
    get noTenantsFound() {
    return !this.isLoading && this.tenants.length === 0;
}

    handleInputChange(event) {
        const fieldName = event.target.name;

        if (fieldName === 'tenantName') {
            this.tenantName = event.target.value;
        } else if (fieldName === 'phoneNumber') {
            this.phoneNumber = event.target.value;
        } else if (fieldName === 'emailAddress') {
            this.emailAddress = event.target.value;
        }
    }

    async handleSaveTenant() {
        if (this.isSaving) {
            return;
        }

        const inputs = [
            ...this.template.querySelectorAll('.tenant-input')
        ];

        const allValid = inputs.reduce((valid, input) => {
            input.reportValidity();
            return input.checkValidity() && valid;
        }, true);

        if (!allValid) {
            return;
        }

        this.isSaving = true;

        try {
            await createTenant({
                tenantName: this.tenantName,
                phoneNumber: this.phoneNumber,
                emailAddress: this.emailAddress
            });

            this.showNewTenantForm = false;
            this.resetForm();

            this.showToast(
                'Success',
                'Tenant created successfully.',
                'success'
            );

            await this.loadTenants();
        } catch (error) {
            this.showToast(
                'Unable to create tenant',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isSaving = false;
        }
    }

    resetForm() {
        this.tenantName = '';
        this.phoneNumber = '';
        this.emailAddress = '';
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
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