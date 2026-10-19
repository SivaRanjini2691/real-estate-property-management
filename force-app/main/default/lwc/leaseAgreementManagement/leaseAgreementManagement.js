import { LightningElement } from 'lwc';

import getLeaseAgreements
    from '@salesforce/apex/LeaseAgreementController.getLeaseAgreements';

import createLeaseAgreement
    from '@salesforce/apex/LeaseAgreementController.createLeaseAgreement';

import getTenantOptions
    from '@salesforce/apex/LeaseAgreementController.getTenantOptions';

import getPropertyOptions
    from '@salesforce/apex/LeaseAgreementController.getPropertyOptions';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { NavigationMixin } from 'lightning/navigation';

// Status options for filtering the lease list.
const STATUS_OPTIONS = [
    { label: 'All Statuses', value: '' },
    { label: 'Draft', value: 'Draft' },
    { label: 'Active', value: 'Active' },
    { label: 'Expired', value: 'Expired' },
    { label: 'Terminated', value: 'Terminated' }
];

// Status options for creating a lease.
// "All Statuses" is intentionally excluded.
const FORM_STATUS_OPTIONS = [
    { label: 'Draft', value: 'Draft' },
    { label: 'Active', value: 'Active' },
    { label: 'Expired', value: 'Expired' },
    { label: 'Terminated', value: 'Terminated' }
];

export default class LeaseAgreementManagement extends NavigationMixin(
    LightningElement
) {
    // --------------------------------------------------
    // LEASE LIST
    // --------------------------------------------------

    leases = [];
    searchKey = '';
    leaseStatus = '';

    isLoading = false;
    isSaving = false;
    showForm = false;

    statusOptions = STATUS_OPTIONS;
    formStatusOptions = FORM_STATUS_OPTIONS;

    // --------------------------------------------------
    // TENANT SELECTION
    // --------------------------------------------------

    tenantId = '';
    tenantOptions = [];
    tenantSearchKey = '';
    selectedTenantLabel = '';
    isLoadingTenants = false;

    // --------------------------------------------------
    // PROPERTY SELECTION
    // --------------------------------------------------

    propertyId = '';
    propertyOptions = [];
    propertySearchKey = '';
    selectedPropertyLabel = '';
    isLoadingProperties = false;

    // --------------------------------------------------
    // LEASE FORM FIELDS
    // --------------------------------------------------

    agreedMonthlyRent = '';
    startDate = '';
    endDate = '';
    leaseTerms = '';
    formStatus = 'Draft';

    // --------------------------------------------------
    // TABLE COLUMNS
    // --------------------------------------------------

    columns = [
        {
            label: 'Lease Number',
            fieldName: 'Name',
            type: 'text'
        },
        {
            label: 'Tenant',
            fieldName: 'tenantName',
            type: 'text'
        },
        {
            label: 'Property',
            fieldName: 'propertyName',
            type: 'text'
        },
        {
            label: 'Monthly Rent',
            fieldName: 'Agreed_Monthly_Rent__c',
            type: 'currency',
            typeAttributes: {
                currencyCode: 'INR',
                maximumFractionDigits: 2
            }
        },
        {
            label: 'Start Date',
            fieldName: 'Start_Date__c',
            type: 'date'
        },
        {
            label: 'End Date',
            fieldName: 'End_Date__c',
            type: 'date'
        },
        {
            label: 'Status',
            fieldName: 'Status__c',
            type: 'text'
        }
    ];

    // --------------------------------------------------
    // LIFECYCLE
    // --------------------------------------------------

    connectedCallback() {
        this.loadLeases();
    }

    // --------------------------------------------------
    // GETTERS
    // --------------------------------------------------

    get hasLeases() {
        return this.leases.length > 0;
    }

    get noLeasesFound() {
        return !this.isLoading && this.leases.length === 0;
    }

    get saveDisabled() {
        return this.isSaving;
    }

    get hasTenantOptions() {
        return this.tenantOptions.length > 0;
    }

    get hasPropertyOptions() {
        return this.propertyOptions.length > 0;
    }

    get noTenantOptionsFound() {
        return (
            !this.isLoadingTenants &&
            this.tenantOptions.length === 0 &&
            this.tenantSearchKey.trim().length > 0
        );
    }

    get noPropertyOptionsFound() {
        return (
            !this.isLoadingProperties &&
            this.propertyOptions.length === 0 &&
            this.propertySearchKey.trim().length > 0
        );
    }

    // --------------------------------------------------
    // LEASE SEARCH AND FILTER
    // --------------------------------------------------

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this.loadLeases();
    }

    handleStatusFilterChange(event) {
        this.leaseStatus = event.detail.value;
        this.loadLeases();
    }

    async loadLeases() {
        this.isLoading = true;

        try {
            const result = await getLeaseAgreements({
                searchKey: this.searchKey || '',
                leaseStatus: this.leaseStatus || ''
            });

            this.leases = (result?.records || []).map((lease) => ({
                ...lease,
                tenantName: lease.Tenant__r?.Name || '—',
                propertyName: lease.Property__r?.Name || '—'
            }));
        } catch (error) {
            this.leases = [];

            this.showToast(
                'Unable to load leases',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    // --------------------------------------------------
    // OPEN AND CLOSE LEASE FORM
    // --------------------------------------------------

    handleNewLease() {
        this.resetForm();
        this.showForm = true;
    }

    handleCloseForm() {
        if (this.isSaving) {
            return;
        }

        this.showForm = false;
        this.resetForm();
    }

    // --------------------------------------------------
    // TENANT SEARCH
    // --------------------------------------------------
async handleTenantSearch(event) {
    const searchKey = event.target.value || '';

    this.tenantSearchKey = searchKey;
    this.tenantId = '';
    this.selectedTenantLabel = '';
    this.tenantOptions = [];

    if (!searchKey.trim()) {
        this.isLoadingTenants = false;
        return;
    }

    this.isLoadingTenants = true;

    const requestedSearch = searchKey;

    try {
        const records = await getTenantOptions({
            searchKey: searchKey.trim()
        });

        // Ignore an outdated response.
        if (this.tenantSearchKey !== requestedSearch) {
            return;
        }

        this.tenantOptions = (records || []).map((tenant) => ({
            label: tenant.Name,
            value: tenant.Id,
            description: tenant.Email__c || ''
        }));
    } catch (error) {
        if (this.tenantSearchKey === requestedSearch) {
            this.tenantOptions = [];

            this.showToast(
                'Tenant search failed',
                this.getErrorMessage(error),
                'error'
            );
        }
    } finally {
        if (this.tenantSearchKey === requestedSearch) {
            this.isLoadingTenants = false;
        }
    }
}

    handleTenantSelect(event) {
        const selectedId = event.currentTarget.dataset.id;

        const selectedTenant = this.tenantOptions.find(
            (tenant) => tenant.value === selectedId
        );

        if (!selectedTenant) {
            return;
        }

        this.tenantId = selectedTenant.value;
        this.selectedTenantLabel = selectedTenant.label;

        this.tenantOptions = [];
        this.tenantSearchKey = '';
    }

    // --------------------------------------------------
    // PROPERTY SEARCH
    // --------------------------------------------------
async handlePropertySearch(event) {
    const searchKey = event.target.value || '';

    this.propertySearchKey = searchKey;
    this.propertyId = '';
    this.selectedPropertyLabel = '';
    this.propertyOptions = [];
    this.agreedMonthlyRent = '';

    if (!searchKey.trim()) {
        this.isLoadingProperties = false;
        return;
    }

    this.isLoadingProperties = true;

    const requestedSearch = searchKey;

    try {
        const records = await getPropertyOptions({
            searchKey: searchKey.trim()
        });

        // Ignore an outdated response.
        if (this.propertySearchKey !== requestedSearch) {
            return;
        }

        this.propertyOptions = (records || []).map((property) => ({
            label: property.Name,
            value: property.Id,
            description:
                `${property.City__c || ''} | ` +
                `₹${property.Rent__c ?? 0} | ` +
                `${property.Status__c || ''}`,
            status: property.Status__c,
            rent: property.Rent__c
        }));
    } catch (error) {
        if (this.propertySearchKey === requestedSearch) {
            this.propertyOptions = [];

            this.showToast(
                'Property search failed',
                this.getErrorMessage(error),
                'error'
            );
        }
    } finally {
        if (this.propertySearchKey === requestedSearch) {
            this.isLoadingProperties = false;
        }
    }
}
    
    handlePropertySelect(event) {
        const selectedId = event.currentTarget.dataset.id;

        const selectedProperty = this.propertyOptions.find(
            (property) => property.value === selectedId
        );

        if (!selectedProperty) {
            return;
        }

        // Do not allow an occupied property to be selected.
        if (selectedProperty.status !== 'Available') {
            this.showToast(
                'Property unavailable',
                'Please select an available property.',
                'warning'
            );
            return;
        }

        this.propertyId = selectedProperty.value;
        this.selectedPropertyLabel = selectedProperty.label;

        // Use the property's listed rent as the initial agreed rent.
        if (selectedProperty.rent !== null &&
            selectedProperty.rent !== undefined) {
            this.agreedMonthlyRent = String(selectedProperty.rent);
        }

        this.propertyOptions = [];
        this.propertySearchKey = '';
    }

    // --------------------------------------------------
    // LEASE FORM INPUTS
    // --------------------------------------------------

    handleInputChange(event) {
        const fieldName = event.target.name;
        const value = event.detail?.value ?? event.target.value;

        switch (fieldName) {
            case 'agreedMonthlyRent':
                this.agreedMonthlyRent = value;
                break;

            case 'startDate':
                this.startDate = value;
                break;

            case 'endDate':
                this.endDate = value;
                break;

            case 'leaseTerms':
                this.leaseTerms = value;
                break;

            case 'formStatus':
                this.formStatus = value;
                break;

            default:
                break;
        }
    }

    // --------------------------------------------------
    // SAVE LEASE
    // --------------------------------------------------

    async handleSaveLease() {
        if (this.isSaving) {
            return;
        }

        // Validate selected records separately.
        if (!this.tenantId) {
            this.showToast(
                'Tenant required',
                'Search for and select a tenant before saving.',
                'error'
            );
            return;
        }

        if (!this.propertyId) {
            this.showToast(
                'Property required',
                'Search for and select an available property before saving.',
                'error'
            );
            return;
        }

        // Validate the remaining form fields.
        const inputs = [
            ...this.template.querySelectorAll('.lease-input')
        ];

        const allValid = inputs.reduce((valid, input) => {
            input.reportValidity();
            return input.checkValidity() && valid;
        }, true);

        if (!allValid) {
            return;
        }

        if (Number(this.agreedMonthlyRent) <= 0) {
            this.showToast(
                'Invalid rent',
                'Agreed monthly rent must be greater than zero.',
                'error'
            );
            return;
        }

        if (new Date(this.endDate) <= new Date(this.startDate)) {
            this.showToast(
                'Invalid dates',
                'The lease end date must be later than its start date.',
                'error'
            );
            return;
        }

        this.isSaving = true;

        try {
            const leaseId = await createLeaseAgreement({
                tenantId: this.tenantId,
                propertyId: this.propertyId,
                agreedMonthlyRent: Number(this.agreedMonthlyRent),
                startDate: this.startDate,
                endDate: this.endDate,
                leaseTerms: this.leaseTerms,
                leaseStatus: this.formStatus
            });

            this.showForm = false;

            this.showToast(
                'Lease created',
                'Lease agreement created successfully.',
                'success'
            );

            this.resetForm();

            await this.loadLeases();

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: leaseId,
                    objectApiName: 'Lease_Agreement__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showToast(
                'Unable to create lease',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isSaving = false;
        }
    }
handleClearSelection(event) {
    const field = event.currentTarget.dataset.field;

    if (field === 'tenant') {
        this.tenantId = '';
        this.selectedTenantLabel = '';
        this.tenantSearchKey = '';
        this.tenantOptions = [];
    }

    if (field === 'property') {
        this.propertyId = '';
        this.selectedPropertyLabel = '';
        this.propertySearchKey = '';
        this.propertyOptions = [];
        this.agreedMonthlyRent = '';
    }
}
    // --------------------------------------------------
    // RESET FORM
    // --------------------------------------------------

    resetForm() {
        this.tenantId = '';
        this.tenantOptions = [];
        this.tenantSearchKey = '';
        this.selectedTenantLabel = '';
        this.isLoadingTenants = false;

        this.propertyId = '';
        this.propertyOptions = [];
        this.propertySearchKey = '';
        this.selectedPropertyLabel = '';
        this.isLoadingProperties = false;

        this.agreedMonthlyRent = '';
        this.startDate = '';
        this.endDate = '';
        this.leaseTerms = '';
        this.formStatus = 'Draft';
    }

    // --------------------------------------------------
    // ERROR HANDLING AND TOASTS
    // --------------------------------------------------

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