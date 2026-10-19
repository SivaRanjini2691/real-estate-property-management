import { LightningElement, api, wire } from 'lwc';

import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import NAME_FIELD from '@salesforce/schema/Property__c.Name';
import ADDRESS_FIELD from '@salesforce/schema/Property__c.Address__c';
import CITY_FIELD from '@salesforce/schema/Property__c.City__c';
import STATE_FIELD from '@salesforce/schema/Property__c.State__c';
import POSTAL_CODE_FIELD from '@salesforce/schema/Property__c.Postal_Code__c';
import COUNTRY_FIELD from '@salesforce/schema/Property__c.Country__c';
import LATITUDE_FIELD from '@salesforce/schema/Property__c.Latitude__c';
import LONGITUDE_FIELD from '@salesforce/schema/Property__c.Longitude__c';

const FIELDS = [
    NAME_FIELD,
    ADDRESS_FIELD,
    CITY_FIELD,
    STATE_FIELD,
    POSTAL_CODE_FIELD,
    COUNTRY_FIELD,
    LATITUDE_FIELD,
    LONGITUDE_FIELD
];

export default class PropertyLocationMap extends LightningElement {
    @api recordId;

    property;
    errorMessage;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: FIELDS
    })
    wiredProperty({ error, data }) {
        if (data) {
            this.property = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.property = undefined;
            this.errorMessage =
                'Unable to load the property location.';
        }
    }

    get propertyName() {
        return this.property
            ? getFieldValue(this.property, NAME_FIELD)
            : '';
    }

    get address() {
        if (!this.property) {
            return '';
        }

        return [
            getFieldValue(this.property, ADDRESS_FIELD),
            getFieldValue(this.property, CITY_FIELD),
            getFieldValue(this.property, STATE_FIELD),
            getFieldValue(this.property, POSTAL_CODE_FIELD),
            getFieldValue(this.property, COUNTRY_FIELD)
        ].filter(Boolean).join(', ');
    }

    get latitude() {
        return this.property
            ? getFieldValue(this.property, LATITUDE_FIELD)
            : null;
    }

    get longitude() {
        return this.property
            ? getFieldValue(this.property, LONGITUDE_FIELD)
            : null;
    }

    get hasCoordinates() {
        return this.latitude !== null &&
            this.latitude !== undefined &&
            this.longitude !== null &&
            this.longitude !== undefined;
    }

    get mapMarkers() {
        if (!this.hasCoordinates) {
            return [];
        }

        return [{
            location: {
                Latitude: Number(this.latitude),
                Longitude: Number(this.longitude)
            },
            title: this.propertyName,
            description: this.address
        }];
    }
}