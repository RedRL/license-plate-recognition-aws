import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatTableModule } from '@angular/material/table';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatNativeDateModule } from '@angular/material/core';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { QueryDbService } from '../../services/query-db.service';

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
    MatNativeDateModule
  ],
  templateUrl: './query-db.component.html',
  styleUrls: ['./query-db.component.scss']
})
export class QueryDbComponent implements OnInit {
  startHour: string | null = null;
  startMinute: string | null = null;
  startSecond: string | null = null;
  endHour: string | null = null;
  endMinute: string | null = null;
  endSecond: string | null = null;

  isDateValid: boolean = false;
  isHourValid: boolean = false;
  isMinuteValid: boolean = false;
  isEndDateValid: boolean = false;
  isEndHourValid: boolean = false;
  isEndMinuteValid: boolean = false;

  startDate: Date | null = null;
  endDate: Date | null = null;
  licensePlates: string = '';
  colors: string = '';
  models: string = '';
  makes: string = '';
  results: any[] = [];

  constructor(private queryDbService: QueryDbService) {}

  ngOnInit(): void {}

  onQuery(): void {
    const startTime = this.combineDateAndTime(this.startDate, this.startHour, this.startMinute, this.startSecond, true);
    const endTime = this.combineDateAndTime(this.endDate, this.endHour, this.endMinute, this.endSecond, false);
    
    const filters = {
      licensePlates: this.licensePlates.split(' ').map((plate: string) => plate.trim()).filter(plate => plate),
      colors: this.colors.split(' ').map((color: string) => color.trim()).filter(color => color),
      models: this.models.split(' ').map((model: string) => model.trim()).filter(model => model),
      makes: this.makes.split(' ').map((make: string) => make.trim()).filter(make => make),
      startTime,
      endTime
    };

    this.queryDbService.queryCars(filters).subscribe(results => {
      this.results = results;
    });
  }

  combineDateAndTime(date: Date | null, hour: string | null, minute: string | null, second: string | null, isStartTime: boolean): Date | null {
    if (!date) return null;
    const combinedDate = new Date(date);
    combinedDate.setHours(hour ? parseInt(hour, 10) : 0);
    combinedDate.setMinutes(minute ? parseInt(minute, 10) : (isStartTime ? 0 : 59));
    combinedDate.setSeconds(second ? parseInt(second, 10) : (isStartTime ? 0 : 59));
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

  validateLicensePlateAndModel(event: KeyboardEvent): void {
    if (!/[a-zA-Z0-9\s]/.test(event.key) && event.key !== 'Backspace' && event.key !== 'Tab') {
      event.preventDefault();
    }
  }

  validateDateInput(event: KeyboardEvent): void {
    if (!/[0-9/]/.test(event.key) && event.key !== 'Backspace' && event.key !== 'Tab') {
      event.preventDefault();
    }
  }

  onDateChange(dateType: 'startDate' | 'endDate'): void {
    if (dateType === 'startDate') {
      this.isDateValid = !!this.startDate;
    } else if (dateType === 'endDate') {
      this.isEndDateValid = !!this.endDate;
    }
  }

  onBlurTimeInput(inputType: 'startHour' | 'startMinute' | 'startSecond' | 'endHour' | 'endMinute' | 'endSecond'): void {
    let value = this[inputType] as string | null;

    if (value !== null && value.length === 1) {
      // If the user enters a single digit, pad it with a leading zero
      this[inputType] = value.padStart(2, '0');
    }
  }

  validateHourInput(hourType: 'startHour' | 'endHour'): void {
    let value = hourType === 'startHour' ? this.startHour : this.endHour;

    if (value === null || value === '') {
      if (hourType === 'startHour') {
        this.startHour = null;
        this.isHourValid = false;
        this.isMinuteValid = false; // Reset minute validity when hour is invalid
      } else {
        this.endHour = null;
        this.isEndHourValid = false;
        this.isEndMinuteValid = false; // Reset minute validity when hour is invalid
      }
      return;
    }

    const parsedValue = parseInt(value, 10);
    if (isNaN(parsedValue) || parsedValue < 0 || parsedValue > 23) {
      if (hourType === 'startHour') {
        this.startHour = '';
        this.isHourValid = false;
        this.isMinuteValid = false; // Reset minute validity when hour is invalid
      } else {
        this.endHour = '';
        this.isEndHourValid = false;
        this.isEndMinuteValid = false; // Reset minute validity when hour is invalid
      }
    } else {
      if (hourType === 'startHour') {
        this.startHour = parsedValue.toString();
        this.isHourValid = true;
      } else {
        this.endHour = parsedValue.toString();
        this.isEndHourValid = true;
      }
    }
  }

  validateMinuteInput(minuteType: 'startMinute' | 'endMinute'): void {
    let value = minuteType === 'startMinute' ? this.startMinute : this.endMinute;

    if (value === null || value === '') {
      if (minuteType === 'startMinute') {
        this.startMinute = null;
        this.isMinuteValid = false;
      } else {
        this.endMinute = null;
        this.isEndMinuteValid = false;
      }
      return;
    }

    const parsedValue = parseInt(value, 10);
    if (isNaN(parsedValue) || parsedValue < 0 || parsedValue > 59) {
      if (minuteType === 'startMinute') {
        this.startMinute = '';
        this.isMinuteValid = false;
      } else {
        this.endMinute = '';
        this.isEndMinuteValid = false;
      }
    } else {
      if (minuteType === 'startMinute') {
        this.startMinute = parsedValue.toString();
        this.isMinuteValid = true;
      } else {
        this.endMinute = parsedValue.toString();
        this.isEndMinuteValid = true;
      }
    }

    // Ensure seconds are disabled if minutes or hours are invalid
    this.isMinuteValid = this.isHourValid && this.isMinuteValid;
    this.isEndMinuteValid = this.isEndHourValid && this.isEndMinuteValid;
  }

  validateSecondInput(secondType: 'startSecond' | 'endSecond'): void {
    let value = secondType === 'startSecond' ? this.startSecond : this.endSecond;

    if (value === null || value === '') {
      if (secondType === 'startSecond') {
        this.startSecond = null;
      } else {
        this.endSecond = null;
      }
      return;
    }

    const parsedValue = parseInt(value, 10);
    if (isNaN(parsedValue) || parsedValue < 0 || parsedValue > 59) {
      if (secondType === 'startSecond') {
        this.startSecond = '';
      } else {
        this.endSecond = '';
      }
    } else {
      if (secondType === 'startSecond') {
        this.startSecond = parsedValue.toString();
      } else {
        this.endSecond = parsedValue.toString();
      }
    }
  }
}
