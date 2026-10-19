import { LightningElement } from 'lwc';

import getProperties
    from '@salesforce/apex/PropertyController.getProperties';

import getNearbyProperties
    from '@salesforce/apex/PropertyController.getNearbyProperties';

import createImageStaging
    from '@salesforce/apex/PropertyController.createImageStaging';

import finalizeProperty
    from '@salesforce/apex/PropertyController.finalizeProperty';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const PAGE_SIZE = 25;

export default class PropertyExplorer extends LightningElement {
    properties = [];
    propertyCards = [];
    errorMessage = '';

    isLoading = false;
    isSaving = false;
    isGettingLocation = false;

    pageNumber = 1;
    pageSize = PAGE_SIZE;
    totalRecords = 0;
    totalPages = 0;

    propertyType = '';
    status = '';
    furnishingStatus = '';
    minRent = '';
    maxRent = '';

    nearbyEnabled = false;
    distanceKm = 10;
    userLatitude;
    userLongitude;

    showNewPropertyModal = false;
    stagingId;
    uploadedFileNames = [];

    acceptedFormats = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp'
    ];

    property = this.getEmptyProperty();

    propertyTypeOptions = [
        { label: 'Residential', value: 'Residential' },
        { label: 'Commercial', value: 'Commercial' }
    ];

    furnishingOptions = [
        { label: 'Furnished', value: 'Furnished' },
        { label: 'Semi-Furnished', value: 'Semi-Furnished' },
        { label: 'Unfurnished', value: 'Unfurnished' }
    ];

    availabilityOptions = [
        { label: 'Available', value: 'Available' },
        { label: 'Occupied', value: 'Occupied' }
    ];

    get hasProperties() {
        return this.propertyCards.length > 0;
    }

    get hasPrevious() {
        return this.pageNumber > 1;
    }

    get hasNext() {
        return this.pageNumber < this.totalPages;
    }

    get hasUploadedImages() {
        return this.uploadedFileNames.length > 0;
    }

    get saveDisabled() {
        return this.isSaving ||
            !this.hasUploadedImages ||
            !this.stagingId;
    }

    get previousDisabled() {
        return this.isLoading || !this.hasPrevious;
    }

    get nextDisabled() {
        return this.isLoading || !this.hasNext;
    }

    get noPropertiesFound() {
        return !this.isLoading &&
            !this.errorMessage &&
            this.propertyCards.length === 0;
    }

    getEmptyProperty() {
        return {
            Name: '',
            Address__c: '',
            City__c: '',
            State__c: '',
            Postal_Code__c: '',
            Country__c: '',
            Property_Type__c: '',
            Furnishing_Status__c: '',
            Status__c: 'Available',
            Rent__c: '',
            Description__c: ''
        };
    }

    connectedCallback() {
        this.loadProperties();
    }

    async loadProperties() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            let result;

            const commonFilters = {
                pageNumber: this.pageNumber,
                pageSize: this.pageSize,
                propertyType: this.propertyType,
                status: this.status,
                furnishingStatus: this.furnishingStatus,
                minRent: this.minRent === ''
                    ? null
                    : Number(this.minRent),
                maxRent: this.maxRent === ''
                    ? null
                    : Number(this.maxRent)
            };

            if (this.nearbyEnabled) {
                const response = await getNearbyProperties({
                    ...commonFilters,
                    userLatitude: this.userLatitude,
                    userLongitude: this.userLongitude,
                    distanceKm: Number(this.distanceKm)
                });

                result = response.result;

                const distances = response.distancesKm || {};

                this.properties = result.records || [];
                this.totalRecords = result.totalRecords || 0;
                this.totalPages = result.totalPages || 0;
                this.pageNumber = result.pageNumber || 1;

                this.propertyCards = this.makePropertyCards(
                    this.properties,
                    result.imageUrls || {},
                    distances
                );
            } else {
                result = await getProperties(commonFilters);

                this.properties = result.records || [];
                this.totalRecords = result.totalRecords || 0;
                this.totalPages = result.totalPages || 0;
                this.pageNumber = result.pageNumber || 1;

                this.propertyCards = this.makePropertyCards(
                    this.properties,
                    result.imageUrls || {},
                    {}
                );
            }
        } catch (error) {
            this.properties = [];
            this.propertyCards = [];
            this.errorMessage = this.getErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    makePropertyCards(records, imageUrls, distances) {
        return records.map(record => {
            const rent = Number(record.Rent__c || 0);
            const imageUrl = imageUrls[record.Id] || '';
            const distance = distances[record.Id];

            return {
                ...record,
                imageUrl,

                location: [
                    record.City__c,
                    record.State__c
                ].filter(Boolean).join(', '),

                formattedRent: new Intl.NumberFormat('en-IN', {
                    style: 'currency',
                    currency: 'INR',
                    maximumFractionDigits: 0
                }).format(rent),

                distanceLabel: distance !== undefined
                    ? `${Number(distance).toFixed(2)} km away`
                    : '',

                showDistance: distance !== undefined,

                statusClass: record.Status__c === 'Available'
                    ? 'status-badge status-available'
                    : 'status-badge status-occupied',

                showImage: Boolean(imageUrl),
                showFallback: !imageUrl
            };
        });
    }

    handleFilterChange(event) {
        const fieldName = event.target.name;

        this[fieldName] =
            event.detail?.value ?? event.target.value;
    }

    async handleUseMyLocation() {
        if (!navigator.geolocation) {
            this.showToast(
                'Location unavailable',
                'Your browser does not support geolocation.',
                'error'
            );
            return;
        }

        this.isGettingLocation = true;

        navigator.geolocation.getCurrentPosition(
            async position => {
                this.userLatitude = position.coords.latitude;
                this.userLongitude = position.coords.longitude;
                this.nearbyEnabled = true;
                this.pageNumber = 1;
                this.isGettingLocation = false;

                await this.loadProperties();

                this.showToast(
                    'Location captured',
                    'Nearby property search is enabled.',
                    'success'
                );
            },
            error => {
                this.isGettingLocation = false;

                let message = 'Unable to retrieve your location.';

                if (error.code === 1) {
                    message =
                        'Location permission was denied. Allow location access in your browser.';
                } else if (error.code === 2) {
                    message = 'Your current location is unavailable.';
                } else if (error.code === 3) {
                    message = 'Location request timed out. Please try again.';
                }

                this.showToast('Location error', message, 'error');
            },
            {
                enableHighAccuracy: true,
                timeout: 15000,
                maximumAge: 60000
            }
        );
    }

    handleNearbyToggle(event) {
        this.nearbyEnabled = event.target.checked;

        if (!this.nearbyEnabled) {
            this.userLatitude = null;
            this.userLongitude = null;
        }
    }

    handleApplyFilters() {
        if (this.nearbyEnabled &&
            (this.userLatitude === undefined ||
             this.userLongitude === undefined)) {
            this.showToast(
                'Location required',
                'Click Use My Location before searching nearby.',
                'warning'
            );
            return;
        }

        const distance = Number(this.distanceKm);

        if (this.nearbyEnabled &&
            (!Number.isFinite(distance) ||
             distance <= 0 ||
             distance > 500)) {
            this.showToast(
                'Invalid distance',
                'Enter a distance greater than 0 and no more than 500 km.',
                'error'
            );
            return;
        }

        if (this.minRent !== '' && this.maxRent !== '' &&
            Number(this.minRent) > Number(this.maxRent)) {
            this.showToast(
                'Invalid rent range',
                'Minimum rent cannot exceed maximum rent.',
                'error'
            );
            return;
        }

        this.pageNumber = 1;
        this.loadProperties();
    }

    handleResetFilters() {
        this.propertyType = '';
        this.status = '';
        this.furnishingStatus = '';
        this.minRent = '';
        this.maxRent = '';

        this.nearbyEnabled = false;
        this.distanceKm = 10;
        this.userLatitude = null;
        this.userLongitude = null;

        this.pageNumber = 1;
        this.loadProperties();
    }

    handlePrevious() {
        if (this.hasPrevious && !this.isLoading) {
            this.pageNumber -= 1;
            this.loadProperties();
        }
    }

    handleNext() {
        if (this.hasNext && !this.isLoading) {
            this.pageNumber += 1;
            this.loadProperties();
        }
    }

    async handleNewProperty() {
        this.resetPropertyForm();
        this.errorMessage = '';
        this.isSaving = true;

        try {
            this.stagingId = await createImageStaging();
            this.showNewPropertyModal = true;
        } catch (error) {
            this.showToast(
                'Unable to start upload',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isSaving = false;
        }
    }

    handleCloseModal() {
        if (this.isSaving) {
            return;
        }

        this.showNewPropertyModal = false;
        this.resetPropertyForm();
    }

    handleInputChange(event) {
        const fieldName = event.target.name;

        this.property = {
            ...this.property,
            [fieldName]: event.detail?.value ?? event.target.value
        };
    }

    handleViewProperty(event) {
        const propertyId = event.currentTarget.dataset.propertyId;

        window.location.assign(
            `/lightning/r/Property__c/${propertyId}/view`
        );
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files || [];

        this.uploadedFileNames = [
            ...this.uploadedFileNames,
            ...uploadedFiles.map(file => file.name)
        ];

        this.showToast(
            'Upload successful',
            `${uploadedFiles.length} file(s) uploaded.`,
            'success'
        );
    }

    handleImageError(event) {
        const propertyId = event.currentTarget.dataset.propertyId;

        this.propertyCards = this.propertyCards.map(card => {
            if (card.Id === propertyId) {
                return {
                    ...card,
                    showImage: false,
                    showFallback: true
                };
            }

            return card;
        });
    }

    resetPropertyForm() {
        this.property = this.getEmptyProperty();
        this.stagingId = null;
        this.uploadedFileNames = [];
        this.errorMessage = '';
    }

    async handleSaveProperty() {
        if (this.isSaving) {
            return;
        }

        const inputs = [
            ...this.template.querySelectorAll('.property-input')
        ];

        const allValid = inputs.reduce((valid, input) => {
            input.reportValidity();
            return valid && input.checkValidity();
        }, true);

        if (!allValid) {
            return;
        }

        if (!this.hasUploadedImages || !this.stagingId) {
            this.errorMessage =
                'Upload at least one property image before saving.';
            return;
        }

        const rent = Number(this.property.Rent__c);

        if (!Number.isFinite(rent) || rent <= 0) {
            this.errorMessage =
                'Monthly rent must be greater than zero.';
            return;
        }

        this.isSaving = true;
        this.errorMessage = '';

        try {
            const propertyRecord = {
                ...this.property,
                Rent__c: rent
            };

            await finalizeProperty({
                propertyRecord,
                stagingId: this.stagingId
            });

            this.showNewPropertyModal = false;

            this.showToast(
                'Property created',
                'The property was saved. Its address was submitted for geocoding.',
                'success'
            );

            this.resetPropertyForm();
            this.pageNumber = 1;

            await this.loadProperties();
        } catch (error) {
            this.errorMessage = this.getErrorMessage(error);
        } finally {
            this.isSaving = false;
        }
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred. Please try again.';
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