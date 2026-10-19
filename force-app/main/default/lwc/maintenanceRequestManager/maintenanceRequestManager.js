import { LightningElement } from 'lwc';
import getMaintenanceRequests
    from '@salesforce/apex/MaintenanceController.getMaintenanceRequests';
import createMaintenanceRequest
    from '@salesforce/apex/MaintenanceController.createMaintenanceRequest';
import updateMaintenanceStatus
    from '@salesforce/apex/MaintenanceController.updateMaintenanceStatus';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const STATUS_OPTIONS = [
    { label: 'Open', value: 'Open' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Cancelled', value: 'Cancelled' }
];

const COLUMNS = [
    {
        label: 'Request Number',
        fieldName: 'Name',
        type: 'text',
        initialWidth: 145
    },
    {
        label: 'Property',
        fieldName: 'propertyName',
        type: 'text',
        wrapText: true
    },
    {
        label: 'Assigned Vendor',
        fieldName: 'vendorName',
        type: 'text',
        wrapText: true
    },
    {
        label: 'Description',
        fieldName: 'Description__c',
        type: 'text',
        wrapText: true
    },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'text',
        initialWidth: 125
    },
    {
        label: 'Assigned Date',
        fieldName: 'Assigned_Date__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Mark In Progress', name: 'in_progress' },
                { label: 'Mark Completed', name: 'completed' },
                { label: 'Reopen', name: 'reopen' },
                { label: 'Cancel Request', name: 'cancel' }
            ]
        }
    }
];

export default class MaintenanceRequestManager extends LightningElement {
    requests = [];
    columns = COLUMNS;

    selectedPropertyId;
    description = '';
    statusFilter = 'All';

    isLoading = false;
    isCreating = false;
    isUpdating = false;

    filterOptions = [
        { label: 'All Requests', value: 'All' },
        ...STATUS_OPTIONS
    ];

    connectedCallback() {
        this.loadRequests();
    }

    get isBusy() {
        return this.isLoading || this.isCreating || this.isUpdating;
    }

    get hasRequests() {
        return this.requests.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && this.requests.length === 0;
    }

    get totalRequests() {
        return this.requests.length;
    }

    get openRequests() {
        return this.requests.filter(
            (request) => request.Status__c === 'Open'
        ).length;
    }

    get inProgressRequests() {
        return this.requests.filter(
            (request) => request.Status__c === 'In Progress'
        ).length;
    }

    get completedRequests() {
        return this.requests.filter(
            (request) => request.Status__c === 'Completed'
        ).length;
    }

    async loadRequests() {
        this.isLoading = true;

        try {
            const data = await getMaintenanceRequests({
                statusFilter: this.statusFilter
            });

            this.requests = (data || []).map((record) => ({
                ...record,
                propertyName: record.Property__r
                    ? record.Property__r.Name
                    : '',
                vendorName: record.Vendor__r
                    ? record.Vendor__r.Name
                    : 'Unassigned'
            }));
        } catch (error) {
            this.showError('Unable to load maintenance requests', error);
        } finally {
            this.isLoading = false;
        }
    }

    handlePropertyChange(event) {
        this.selectedPropertyId = event.detail.recordId;
    }

    handleDescriptionChange(event) {
        this.description = event.detail.value;
    }

    handleFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.loadRequests();
    }

    handleRefresh() {
        this.loadRequests();
    }

    async handleCreateRequest() {
        const propertyPicker = this.template.querySelector(
            'lightning-record-picker'
        );

        const descriptionInput = this.template.querySelector(
            'lightning-textarea'
        );

        const propertyValid = propertyPicker.reportValidity();
        const descriptionValid = descriptionInput.reportValidity();

        if (!propertyValid || !descriptionValid) {
            return;
        }

        if (!this.selectedPropertyId || !this.description.trim()) {
            this.showToast(
                'Missing Information',
                'Select a property and enter a maintenance description.',
                'warning'
            );
            return;
        }

        this.isCreating = true;

        try {
            await createMaintenanceRequest({
                propertyId: this.selectedPropertyId,
                description: this.description
            });

            this.showToast(
                'Success',
                'Maintenance request created and vendor assignment processed.',
                'success'
            );

            this.selectedPropertyId = undefined;
            this.description = '';

            propertyPicker.clearSelection();

            await this.loadRequests();
        } catch (error) {
            this.showError('Unable to create maintenance request', error);
        } finally {
            this.isCreating = false;
        }
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const requestRecord = event.detail.row;

        const statusByAction = {
            in_progress: 'In Progress',
            completed: 'Completed',
            reopen: 'Open',
            cancel: 'Cancelled'
        };

        const newStatus = statusByAction[actionName];

        if (!newStatus) {
            return;
        }

        if (requestRecord.Status__c === newStatus) {
            this.showToast(
                'No Change',
                `This request is already ${newStatus}.`,
                'info'
            );
            return;
        }

        this.isUpdating = true;

        try {
            await updateMaintenanceStatus({
                requestId: requestRecord.Id,
                newStatus
            });

            this.showToast(
                'Status Updated',
                `${requestRecord.Name} is now ${newStatus}.`,
                'success'
            );

            await this.loadRequests();
        } catch (error) {
            this.showError('Unable to update maintenance status', error);
        } finally {
            this.isUpdating = false;
        }
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

    showError(title, error) {
        let message = 'An unexpected error occurred.';

        if (error?.body?.message) {
            message = error.body.message;
        } else if (error?.message) {
            message = error.message;
        }

        this.showToast(title, message, 'error');
    }
}
