import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatTableModule } from '@angular/material/table';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatNativeDateModule } from '@angular/material/core';
import { MatAutocompleteModule } from '@angular/material/autocomplete';
import { MatSelectModule } from '@angular/material/select';
import { MatChipsModule } from '@angular/material/chips';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { Observable, map, startWith, forkJoin } from 'rxjs';
import { QueryDbService } from '../../services/query-db.service';
import { COMMA, ENTER } from '@angular/cdk/keycodes';
import { MatChipInputEvent } from '@angular/material/chips';
import { MatAutocompleteSelectedEvent } from '@angular/material/autocomplete';

@Component({
  selector: 'app-query-db',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    MatButtonModule,
    MatIconModule,
    MatCardModule,
    MatInputModule,
    MatFormFieldModule,
    MatTableModule,
    MatDatepickerModule,
    MatNativeDateModule,
    MatAutocompleteModule,
    MatSelectModule,
    MatChipsModule,
    MatIconModule
  ],
  templateUrl: './query-db.component.html',
  styleUrls: ['./query-db.component.scss']
})
export class QueryDbComponent implements OnInit, OnDestroy {
  timeHour: string | null = null;
  timeMinute: string | null = null;
  timeSecond: string | null = null;

  timeDate: Date | null = null;
  selectedLicensePlates: string[] = [];
  selectedColors: string[] = [];
  selectedModels: string[] = [];
  selectedMakes: string[] = [];
  results: any[] = [];
  queryExecuted: boolean = false;
  
  // Chip separator key codes (only ENTER, no comma)
  readonly separatorKeysCodes = [ENTER] as const;

  // Autocomplete options
  plateOptions: string[] = [];
  colorOptions: string[] = [];
  makeOptions: string[] = [];
  modelOptions: string[] = [];

  // Filtered autocomplete options
  filteredPlateOptions: Observable<string[]> = new Observable();
  filteredColorOptions: Observable<string[]> = new Observable();
  filteredMakeOptions: Observable<string[]> = new Observable();
  filteredModelOptions: Observable<string[]> = new Observable();

  // Edit functionality
  editingRows: Set<number> = new Set();
  hasChanges: boolean = false;
  originalData: Map<number, any> = new Map(); // Temporary storage during single edit
  initialValues: Map<number, any> = new Map(); // Permanent storage of original values
  modifiedRows: Map<number, any> = new Map();
  actualChanges: Map<number, any> = new Map(); // Track actual value changes

  constructor(private queryDbService: QueryDbService) {}

  ngOnInit(): void {
    // Load autocomplete options
    this.loadAutocompleteOptions();
    
    // Add document click listener for canceling edits
    document.addEventListener('click', this.onDocumentClick.bind(this));
  }

  ngOnDestroy(): void {
    // Clean up document click listener
    document.removeEventListener('click', this.onDocumentClick.bind(this));
  }

  onDocumentClick(event: MouseEvent): void {
    if (this.editingRows.size > 0) {
      const target = event.target as HTMLElement;
      // Don't exit if clicking on input fields, buttons, or form elements
      if (!target.closest('input') && !target.closest('button') && !target.closest('mat-form-field') && !target.closest('.edit-field')) {
        this.exitAllEditModes();
      }
    }
  }

  loadAutocompleteOptions(): void {
    // Load options for each field
    this.queryDbService.getAutocompleteOptions('plate_number').subscribe(options => {
      this.plateOptions = options;
    });

    this.queryDbService.getAutocompleteOptions('color').subscribe(options => {
      this.colorOptions = options;
    });

    this.queryDbService.getAutocompleteOptions('make').subscribe(options => {
      this.makeOptions = options;
    });

    this.queryDbService.getAutocompleteOptions('model').subscribe(options => {
      this.modelOptions = options;
    });
  }

  private filterOptions(value: string, options: string[]): string[] {
    const filterValue = value.toLowerCase();
    return options.filter(option => option.toLowerCase().includes(filterValue));
  }

  onQuery(): void {
    // Format date to YYYY-MM-DD without timezone offset
    let formattedDate = null;
    if (this.timeDate) {
      const year = this.timeDate.getFullYear();
      const month = String(this.timeDate.getMonth() + 1).padStart(2, '0');
      const day = String(this.timeDate.getDate()).padStart(2, '0');
      formattedDate = `${year}-${month}-${day}`;
    }
    
    const filters = {
      licensePlates: this.selectedLicensePlates,
      colors: this.selectedColors,
      models: this.selectedModels,
      makes: this.selectedMakes,
      queryDate: formattedDate,
      queryHour: this.timeHour ? parseInt(this.timeHour, 10) : null,
      queryMinute: this.timeMinute ? parseInt(this.timeMinute, 10) : null,
      querySecond: this.timeSecond ? parseInt(this.timeSecond, 10) : null
    };

    this.queryDbService.queryCars(filters).subscribe(results => {
      // Convert UTC timestamps to local time
      this.results = results.map((result: any) => ({
        ...result,
        time: this.convertUTCToLocal(result.time)
      }));
      this.queryExecuted = true;
    });
  }

  convertUTCToLocal(utcTimeString: string): string {
    // Parse the UTC time string (supports both "YYYY-MM-DD HH:MM:SS" and ISO format)
    let utcDate: Date;
    
    // Check if it's already in ISO format (contains 'T')
    if (utcTimeString.includes('T')) {
      utcDate = new Date(utcTimeString);
    } else {
      // Old format: "YYYY-MM-DD HH:MM:SS"
      utcDate = new Date(utcTimeString + ' UTC');
    }
    
    // Format to local time
    const year = utcDate.getFullYear();
    const month = String(utcDate.getMonth() + 1).padStart(2, '0');
    const day = String(utcDate.getDate()).padStart(2, '0');
    const hours = String(utcDate.getHours()).padStart(2, '0');
    const minutes = String(utcDate.getMinutes()).padStart(2, '0');
    const seconds = String(utcDate.getSeconds()).padStart(2, '0');
    
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }

  combineDateAndTime(date: Date | null, hour: string | null, minute: string | null, second: string | null): Date | null {
    if (!date) return null;
    const combinedDate = new Date(date);
    combinedDate.setHours(hour ? parseInt(hour, 10) : 0);
    combinedDate.setMinutes(minute ? parseInt(minute, 10) : 0);
    combinedDate.setSeconds(second ? parseInt(second, 10) : 0);
    return combinedDate;
  }

  validateNumbers(event: KeyboardEvent): void {
    const input = event.target as HTMLInputElement;

    // Allow only numbers, Backspace, Tab, Arrow keys, and overwriting if all input is selected
    if (!/[0-9]/.test(event.key) && event.key !== 'Backspace' && event.key !== 'Tab' && event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
      event.preventDefault();
    }

    // Allow input replacement if all text is selected
    if (input.selectionStart !== null && input.selectionEnd !== null) {
      if (input.selectionStart !== input.selectionEnd) {
        return; // Allow replacement
      }
    }

    // Prevent input beyond two digits
    if (input.value.length >= 2 && event.key !== 'Backspace' && event.key !== 'Tab' && event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
      event.preventDefault();
    }
  }

  validateLetters(event: KeyboardEvent): void {
    if (!/[a-zA-Z\s]/.test(event.key) && event.key !== 'Backspace' && event.key !== 'Tab') {
      event.preventDefault();
    }
  }

  validateLettersAndSemicolon(event: KeyboardEvent): void {
    if (!/[a-zA-Z;]/.test(event.key) && event.key !== 'Backspace' && event.key !== 'Tab') {
      event.preventDefault();
    }
  }

  validateLicensePlateAndModel(event: KeyboardEvent): void {
    if (!/[a-zA-Z0-9\s]/.test(event.key) && event.key !== 'Backspace' && event.key !== 'Tab') {
      event.preventDefault();
    }
  }

  validateLicensePlateModelAndSemicolon(event: KeyboardEvent): void {
    if (!/[a-zA-Z0-9;]/.test(event.key) && event.key !== 'Backspace' && event.key !== 'Tab') {
      event.preventDefault();
    }
  }

  validateDateInput(event: KeyboardEvent): void {
    if (!/[0-9/]/.test(event.key) && event.key !== 'Backspace' && event.key !== 'Tab') {
      event.preventDefault();
    }
  }

  onBlurTimeInput(inputType: 'timeHour' | 'timeMinute' | 'timeSecond'): void {
    let value = this[inputType] as string | null;

    if (value !== null && value.length === 1) {
      // If the user enters a single digit, pad it with a leading zero
      this[inputType] = value.padStart(2, '0');
    }
  }

  validateHourInput(hourType: 'timeHour'): void {
    let value = this.timeHour;

    if (value === null || value === '') {
      this.timeHour = null;
      return;
    }

    const parsedValue = parseInt(value, 10);
    if (isNaN(parsedValue) || parsedValue < 0 || parsedValue > 23) {
      this.timeHour = '';
    } else {
      this.timeHour = parsedValue.toString();
    }
  }

  validateMinuteInput(minuteType: 'timeMinute'): void {
    let value = this.timeMinute;

    if (value === null || value === '') {
      this.timeMinute = null;
      return;
    }

    const parsedValue = parseInt(value, 10);
    if (isNaN(parsedValue) || parsedValue < 0 || parsedValue > 59) {
      this.timeMinute = '';
    } else {
      this.timeMinute = parsedValue.toString();
    }
  }

  validateSecondInput(secondType: 'timeSecond'): void {
    let value = this.timeSecond;

    if (value === null || value === '') {
      this.timeSecond = null;
      return;
    }

    const parsedValue = parseInt(value, 10);
    if (isNaN(parsedValue) || parsedValue < 0 || parsedValue > 59) {
      this.timeSecond = '';
      } else {
      this.timeSecond = parsedValue.toString();
    }
  }

  // Edit functionality methods
  onDoubleClick(event: MouseEvent, row: any, index: number, fieldName: string): void {
    event.stopPropagation();
    this.editRow(row, index);
    
    // Auto-focus the specific field that was clicked after a brief delay to allow Angular to render
    setTimeout(() => {
      const editField = document.getElementById('edit-' + fieldName + '-' + index) as HTMLInputElement;
      if (editField) {
        editField.focus();
        editField.select(); // Also select the text for easy editing
      }
    }, 100);
  }



  exitAllEditModes(): void {
    this.editingRows.forEach(index => {
      const original = this.originalData.get(index);
      if (original) {
        Object.assign(this.results[index], original);
      }
    });
    this.editingRows.clear();
    this.originalData.clear();
  }

  editRow(row: any, index: number): void {
    this.editingRows.add(index);
    // Store original data for potential rollback
    this.originalData.set(index, { ...row });
    
    // Store initial values only if not already stored (first time editing this row)
    if (!this.initialValues.has(index)) {
      this.initialValues.set(index, { ...row });
    }
  }

  saveRow(row: any, index: number): void {
    this.editingRows.delete(index);
    
    // Format the values before saving to database
    if (row.licensePlate) {
      row.licensePlate = row.licensePlate.replace(/[^a-zA-Z0-9-]/g, '');
    }
    if (row.color) {
      row.color = this.toTitleCase(row.color.replace(/[^a-zA-Z- ]/g, '')).toLowerCase();
    }
    if (row.make) {
      row.make = this.toTitleCase(row.make.replace(/[^a-zA-Z- ]/g, ''));
    }
    if (row.model) {
      row.model = this.toTitleCase(row.model.replace(/[^a-zA-Z0-9- ]/g, ''));
    }
    
    // Update the results array to reflect the formatted values in the UI
    this.results[index] = { ...row };
    
    // Check if actual changes were made compared to INITIAL values (not last edit)
    const initial = this.initialValues.get(index);
    
    if (initial) {
      // Compare each field to initial values
      const hasLicensePlateChange = row.licensePlate !== initial.licensePlate;
      const hasColorChange = row.color !== initial.color;
      const hasMakeChange = row.make !== initial.make;
      const hasModelChange = row.model !== initial.model;
      
      const hasActualChanges = hasLicensePlateChange || hasColorChange || hasMakeChange || hasModelChange;
      
      if (hasActualChanges) {
        // Add or update the change
        this.actualChanges.set(index, { ...row });
        this.modifiedRows.set(index, { ...row });
      } else {
        // No changes - remove from actualChanges if it exists
        this.actualChanges.delete(index);
        this.modifiedRows.delete(index);
      }
    }
    
    this.originalData.delete(index);
    this.hasChanges = true;
  }

  saveAllEditingRows(): void {
    // Save all currently editing rows
    this.editingRows.forEach(index => {
      const row = this.results[index];
      if (row) {
        this.saveRow(row, index);
      }
    });
  }

  cancelEdit(row: any, index: number): void {
    // Restore original data
    const original = this.originalData.get(index);
    if (original) {
      Object.assign(row, original);
    }
    this.editingRows.delete(index);
    this.originalData.delete(index);
  }

  isEditing(index: number): boolean {
    return this.editingRows.has(index);
  }

  updateDatabase(): void {
    // Auto-save any currently editing rows
    this.saveAllEditingRows();
    
    if (this.actualChanges.size === 0) return;
    
    console.log('Updating database with actual changes...');
    
    // Process only rows with actual changes
    const updateObservables: Observable<any>[] = [];
    
    this.actualChanges.forEach((rowData, index) => {
      const plateId = rowData.id;
      if (plateId) {
        const updateData = {
          licensePlate: rowData.licensePlate,
          color: rowData.color,
          make: rowData.make,
          model: rowData.model
        };
        
        console.log('Updating plate ID:', plateId, 'with data:', updateData);
        const observable = this.queryDbService.updatePlate(plateId, updateData);
        updateObservables.push(observable);
      }
    });
    
    if (updateObservables.length === 0) {
      console.log('No actual changes to process');
      return;
    }
    
    forkJoin(updateObservables).subscribe({
      next: (results) => {
        console.log('All updates completed successfully:', results);
        this.hasChanges = false;
        this.modifiedRows.clear();
        this.actualChanges.clear();
        this.initialValues.clear(); // Clear initial values after successful update
        
        // Refresh autocomplete options
        this.loadAutocompleteOptions();
        
        alert(`Database updated successfully! Updated ${updateObservables.length} record(s).`);
      },
      error: (error) => {
        console.error('Update failed:', error);
        alert('Failed to update database. Please try again.');
      }
    });
  }

  onFieldChange(): void {
    this.hasChanges = true;
  }

  // Chip management methods
  addPlate(event: MatChipInputEvent): void {
    const value = (event.value || '').trim();
    if (value && !this.selectedLicensePlates.includes(value)) {
      // Allow only letters, numbers, and dash for license plates
      const filteredValue = value.replace(/[^a-zA-Z0-9-]/g, '');
      if (filteredValue) {
        this.selectedLicensePlates.push(filteredValue);
      }
    }
    event.chipInput!.clear();
  }

  removePlate(plate: string): void {
    const index = this.selectedLicensePlates.indexOf(plate);
    if (index >= 0) {
      this.selectedLicensePlates.splice(index, 1);
    }
  }

  plateSelected(event: MatAutocompleteSelectedEvent, input: HTMLInputElement): void {
    const value = event.option.viewValue;
    if (!this.selectedLicensePlates.includes(value)) {
      // Allow only letters, numbers, and dash for license plates
      const filteredValue = value.replace(/[^a-zA-Z0-9-]/g, '');
      if (filteredValue) {
        this.selectedLicensePlates.push(filteredValue);
      }
    }
    input.value = '';
  }

  isPlateSelected(option: string): boolean {
    return this.selectedLicensePlates.includes(option);
  }

  addColor(event: MatChipInputEvent): void {
    const value = (event.value || '').trim();
    if (value && !this.selectedColors.includes(value)) {
      // Allow only letters, dash, and space for color and convert to lowercase
      const filteredValue = this.toTitleCase(value.replace(/[^a-zA-Z- ]/g, '')).toLowerCase();
      if (filteredValue) {
        this.selectedColors.push(filteredValue);
      }
    }
    event.chipInput!.clear();
  }

  removeColor(color: string): void {
    const index = this.selectedColors.indexOf(color);
    if (index >= 0) {
      this.selectedColors.splice(index, 1);
    }
  }

  colorSelected(event: MatAutocompleteSelectedEvent, input: HTMLInputElement): void {
    const value = event.option.viewValue;
    if (!this.selectedColors.includes(value)) {
      // Allow only letters, dash, and space for color and convert to lowercase
      const filteredValue = this.toTitleCase(value.replace(/[^a-zA-Z- ]/g, '')).toLowerCase();
      if (filteredValue) {
        this.selectedColors.push(filteredValue);
      }
    }
    input.value = '';
  }

  isColorSelected(option: string): boolean {
    return this.selectedColors.includes(option);
  }

  addModel(event: MatChipInputEvent): void {
    const value = (event.value || '').trim();
    if (value && !this.selectedModels.includes(value)) {
      // Allow only letters, numbers, dash, and space for model, convert to Title Case
      const filteredValue = value.replace(/[^a-zA-Z0-9- ]/g, '');
      if (filteredValue) {
        const titleCaseValue = this.toTitleCase(filteredValue);
        this.selectedModels.push(titleCaseValue);
      }
    }
    event.chipInput!.clear();
  }

  removeModel(model: string): void {
    const index = this.selectedModels.indexOf(model);
    if (index >= 0) {
      this.selectedModels.splice(index, 1);
    }
  }

  modelSelected(event: MatAutocompleteSelectedEvent, input: HTMLInputElement): void {
    const value = event.option.viewValue;
    if (!this.selectedModels.includes(value)) {
      // Allow only letters, numbers, dash, and space for model, convert to Title Case
      const filteredValue = value.replace(/[^a-zA-Z0-9- ]/g, '');
      if (filteredValue) {
        const titleCaseValue = this.toTitleCase(filteredValue);
        this.selectedModels.push(titleCaseValue);
      }
    }
    input.value = '';
  }

  isModelSelected(option: string): boolean {
    return this.selectedModels.includes(option);
  }

  addMake(event: MatChipInputEvent): void {
    const value = (event.value || '').trim();
    if (value && !this.selectedMakes.includes(value)) {
      // Allow only letters, dash, and space for make, convert to Title Case
      const filteredValue = value.replace(/[^a-zA-Z- ]/g, '');
      if (filteredValue) {
        const titleCaseValue = this.toTitleCase(filteredValue);
        this.selectedMakes.push(titleCaseValue);
      }
    }
    event.chipInput!.clear();
  }

  removeMake(make: string): void {
    const index = this.selectedMakes.indexOf(make);
    if (index >= 0) {
      this.selectedMakes.splice(index, 1);
    }
  }

  makeSelected(event: MatAutocompleteSelectedEvent, input: HTMLInputElement): void {
    const value = event.option.viewValue;
    if (!this.selectedMakes.includes(value)) {
      // Allow only letters, dash, and space for make, convert to Title Case
      const filteredValue = value.replace(/[^a-zA-Z- ]/g, '');
      if (filteredValue) {
        const titleCaseValue = this.toTitleCase(filteredValue);
        this.selectedMakes.push(titleCaseValue);
      }
    }
    input.value = '';
  }

  isMakeSelected(option: string): boolean {
    return this.selectedMakes.includes(option);
  }

  // Helper function to convert to Title Case (preserves spaces and dashes)
  private toTitleCase(str: string): string {
    // First clean up multiple spaces and trim
    const cleaned = str.replace(/\s+/g, ' ').trim();
    
    return cleaned
      .split(/([- ])/) // Split by dash or space but keep the separators
      .map(word => {
        if (word === '-' || word === ' ') {
          return word; // Keep separators as-is
        }
        return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
      })
      .join('');
  }

  // Keydown handlers to prevent invalid characters from being typed
  onLicensePlateKeyDown(event: KeyboardEvent): boolean {
    const key = event.key;
    // Allow only letters, numbers, and dash
    if (!/[a-zA-Z0-9-]/.test(key)) {
      event.preventDefault();
      return false;
    }
    return true;
  }

  onColorKeyDown(event: KeyboardEvent): boolean {
    const key = event.key;
    // Allow only letters, dash, and space
    if (!/[a-zA-Z- ]/.test(key) && key !== ' ') {
      event.preventDefault();
      return false;
    }
    return true;
  }

  onMakeKeyDown(event: KeyboardEvent): boolean {
    const key = event.key;
    // Allow only letters, dash, and space
    if (!/[a-zA-Z- ]/.test(key) && key !== ' ') {
      event.preventDefault();
      return false;
    }
    return true;
  }

  onModelKeyDown(event: KeyboardEvent): boolean {
    const key = event.key;
    // Allow only letters, numbers, dash, and space
    if (!/[a-zA-Z0-9- ]/.test(key) && key !== ' ') {
      event.preventDefault();
      return false;
    }
    return true;
  }

}
